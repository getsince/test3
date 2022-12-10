defmodule T.Media do
  @moduledoc "Functions to interact with user generated and static media on AWS S3"
  alias __MODULE__.{Static, Client}

  # TODO use mox in test env

  @doc """
  Bucket for user-generated content. Like photos.
  """
  def user_bucket, do: bucket(:user_bucket)

  @doc """
  Bucket for static content, like stickers.
  """
  def static_bucket, do: bucket(:static_bucket)

  defp static_cdn_endpoint, do: cdn_endpoint(:static_cdn)

  @doc """
  Bucket for media content, like audio and video.
  """
  def media_bucket, do: bucket(:media_bucket)

  defp media_cdn_endpoint, do: cdn_endpoint(:media_cdn)

  defp cdn_endpoint(name) do
    Application.fetch_env!(:t, __MODULE__)[name]
  end

  defp bucket(name) do
    Application.fetch_env!(:t, __MODULE__)[name]
  end

  # TODO use presigned urls for photos as well
  @doc "Returns a pre-signed URL for an object"
  def user_presigned_url(method \\ :get, key) do
    presigned_url(method, user_bucket(), key)
  end

  # def static_presigned_url(method \\ :get, key) do
  #   presigned_url(method, static_bucket(), key)
  # end

  defp presigned_url(method, bucket, key) do
    {:ok, url} = ExAws.S3.presigned_url(ExAws.Config.new(:s3), method, bucket, key)
    url
  end

  @doc """
  Builds a URL to an image on S3 that gets resized by imgproxy and cached by a CDN.

  Accepts `opts` that are passed to imgproxy URL builder.
  """
  def user_imgproxy_cdn_url(url_or_s3_key, requested_width, opts \\ [])

  def user_imgproxy_cdn_url("http" <> _rest = source_url, requested_width, opts) do
    width = if opts[:force_width], do: requested_width, else: image_width_bucket(requested_width)

    # TODO sharpen?
    Imgproxy.url(source_url,
      width: width,
      height: 0,
      enlarge: "0",
      resize: "fit"
    )
  end

  def user_imgproxy_cdn_url(s3_key, requested_width, opts) do
    user_imgproxy_cdn_url(user_s3_url(s3_key), requested_width, opts)
  end

  defp static_cdn_url(s3_key) do
    Path.join([static_cdn_endpoint(), URI.encode(s3_key)])
  end

  def media_cdn_url(s3_key) do
    Path.join([media_cdn_endpoint(), URI.encode(s3_key)])
  end

  def static_s3_url, do: s3_url(static_bucket())
  def user_s3_url, do: s3_url(user_bucket())
  def media_s3_url, do: s3_url(media_bucket())

  # TODO make private
  def user_s3_url(s3_key) do
    Path.join([user_s3_url(), s3_key])
  end

  defp s3_url(bucket) do
    "https://#{bucket}.s3.amazonaws.com"
  end

  def user_file_exists?(key) do
    user_bucket()
    |> ExAws.S3.head_object(key)
    |> ExAws.request()
    |> case do
      {:ok, %{status_code: 200}} -> true
      {:error, {:http_error, 404, %{status_code: 404}}} -> false
    end
  end

  def presign_config do
    env = Application.get_all_env(:ex_aws)

    %{
      region: Application.fetch_env!(:ex_aws, :region),
      access_key_id: env[:access_key_id] || System.fetch_env!("AWS_ACCESS_KEY_ID"),
      secret_access_key: env[:secret_access_key] || System.fetch_env!("AWS_SECRET_ACCESS_KEY")
    }
  end

  # https://gist.github.com/chrismccord/37862f1f8b1f5148644b75d20d1cb073
  # Dependency-free S3 Form Upload using HTTP POST sigv4

  # https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-post-example.html

  @doc """
  Signs a form upload.

  The configuration is a map which must contain the following keys:

    * `:region` - The AWS region, such as "us-east-1"
    * `:access_key_id` - The AWS access key id
    * `:secret_access_key` - The AWS secret access key


  Returns a map of form fields to be used on the client via the JavaScript `FormData` API.

  ## Options

    * `:key` - The required key of the object to be uploaded.
    * `:max_file_size` - The required maximum allowed file size in bytes.
    * `:content_type` - The required MIME type of the file to be uploaded.
    * `:expires_in` - The required expiration time in milliseconds from now
      before the signed upload expires.
    * `:acl` - ACL to apply to the object, defaults to `"private"`.

  ## Examples

      config = %{
        region: "us-east-1",
        access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")
      }

      {:ok, fields} =
        sign_form_upload(config, "my-bucket",
          key: "public/my-file-name",
          content_type: "image/png",
          max_file_size: 10_000,
          expires_in: :timer.hours(1)
        )

  """
  def sign_form_upload(config \\ presign_config(), bucket \\ user_bucket(), opts) do
    key = Keyword.fetch!(opts, :key)
    max_file_size = Keyword.fetch!(opts, :max_file_size)
    content_type = Keyword.fetch!(opts, :content_type)
    expires_in = Keyword.fetch!(opts, :expires_in)
    acl = opts[:acl] || "private"

    expires_at = DateTime.add(DateTime.utc_now(), expires_in, :millisecond)
    amz_date = amz_date(expires_at)
    credential = credential(config, expires_at)

    encoded_policy =
      Base.encode64("""
      {
        "expiration": "#{DateTime.to_iso8601(expires_at)}",
        "conditions": [
          {"bucket": "#{bucket}"},
          ["eq", "$key", "#{key}"],
          {"acl": "#{acl}"},
          ["eq", "$Content-Type", "#{content_type}"],
          ["content-length-range", 0, #{max_file_size}],
          {"x-amz-server-side-encryption": "AES256"},
          {"x-amz-credential": "#{credential}"},
          {"x-amz-algorithm": "AWS4-HMAC-SHA256"},
          {"x-amz-date": "#{amz_date}"}
        ]
      }
      """)

    fields = %{
      "key" => key,
      "acl" => acl,
      "content-type" => content_type,
      "x-amz-server-side-encryption" => "AES256",
      "x-amz-credential" => credential,
      "x-amz-algorithm" => "AWS4-HMAC-SHA256",
      "x-amz-date" => amz_date,
      "policy" => encoded_policy,
      "x-amz-signature" => signature(config, expires_at, encoded_policy)
    }

    {:ok, fields}
  end

  defp amz_date(time) do
    time
    |> NaiveDateTime.to_iso8601()
    |> String.split(".")
    |> List.first()
    |> String.replace("-", "")
    |> String.replace(":", "")
    |> Kernel.<>("Z")
  end

  defp credential(%{} = config, %DateTime{} = expires_at) do
    "#{config.access_key_id}/#{short_date(expires_at)}/#{config.region}/s3/aws4_request"
  end

  defp signature(config, %DateTime{} = expires_at, encoded_policy) do
    config
    |> signing_key(expires_at, "s3")
    |> sha256(encoded_policy)
    |> Base.encode16(case: :lower)
  end

  defp signing_key(%{} = config, %DateTime{} = expires_at, service) when service in ["s3"] do
    amz_date = short_date(expires_at)
    %{secret_access_key: secret, region: region} = config

    ("AWS4" <> secret)
    |> sha256(amz_date)
    |> sha256(region)
    |> sha256(service)
    |> sha256("aws4_request")
  end

  defp short_date(%DateTime{} = expires_at) do
    expires_at
    |> amz_date()
    |> String.slice(0..7)
  end

  defp sha256(secret, msg), do: :crypto.mac(:hmac, :sha256, secret, msg)

  def sticker_cache_busting_cdn_url(key, e_tag) do
    static_cdn_url(key) <> "?d=" <> e_tag
  end

  def sticker_cache_busting_cdn_url(%Static.Object{key: key, e_tag: e_tag}) do
    sticker_cache_busting_cdn_url(key, e_tag)
  end

  def known_sticker_url(key) do
    if etag = Static.lookup_etag(key) do
      sticker_cache_busting_cdn_url(key, etag)
    end
  end

  def known_stickers do
    Map.new(Static.list(), fn %Static.Object{key: key, e_tag: e_tag} ->
      {key, sticker_cache_busting_cdn_url(key, e_tag)}
    end)
  end

  def list_static_files do
    Client.list_objects(static_bucket())
  end

  def delete_sticker_by_key(key) do
    result =
      static_bucket()
      |> ExAws.S3.delete_object(key)
      |> ExAws.request!(region: "eu-north-1")

    Static.notify_s3_updated()

    result
  end

  def rename_static_file(from_key, to_key) do
    bucket = static_bucket()
    opts = [region: "eu-north-1"]

    # TODO copied object is not public
    %{status_code: 200} =
      copy_result =
      bucket
      |> ExAws.S3.put_object_copy(to_key, bucket, from_key)
      |> ExAws.request!(opts)

    %{status_code: 204} =
      delete_result =
      bucket
      |> ExAws.S3.delete_object(from_key)
      |> ExAws.request!(opts)

    Static.notify_s3_updated()
    [copy_result, delete_result]
  end

  @doc """
  Related: https://cloud.google.com/storage/docs/gsutil/addlhelp/Filenameencodingandinteroperabilityproblems

  Example:

      iex> String.codepoints("ай")
      ["а", "и", "̆"]

      iex> fix_macos_unicode("ай") |> String.codepoints()
      ["а", "й"]

      iex> String.codepoints("йё")
      ["и", "̆", "е", "̈"]

      iex> fix_macos_unicode("йё") |> String.codepoints()
      ["й", "ё"]

  """
  def fix_macos_unicode(key) do
    String.replace(key, ["й", "ё"], fn
      "й" -> "й"
      "ё" -> "ё"
    end)
  end

  @doc """
  Picks a width bucket for the requested width, where width is measured in pixels.

  Related: https://iosref.com/res

  Example:

      # iPhone 12 Pro Max
      iex> image_width_bucket(1284)
      1200

      # iPhone 12 / 12 Pro
      iex> image_width_bucket(1170)
      1200

      # iPhone 12 mini
      iex> image_width_bucket(1080)
      1000

      # iPhone 11 Pro Max and XS Max
      iex> image_width_bucket(1242)
      1200

      # iPhone 11 Pro and XS, X
      iex> image_width_bucket(1125)
      1200

      # iPhone 11 and XR
      iex> image_width_bucket(828)
      800

      # iPhone 8+ and 7+, 6s+, 6+
      iex> image_width_bucket(1242)
      1200

      # iPhone SE (gen 2) and 8, 7, 6s, 6
      iex> image_width_bucket(750)
      800

      # iPhone SE (gen 1) and 5s, 5c, 5
      iex> image_width_bucket(640)
      800

  """
  def image_width_bucket(requested_width) do
    cond do
      requested_width >= 1100 -> 1200
      requested_width >= 900 -> 1000
      requested_width <= 300 -> 250
      true -> 800
    end
  end
end

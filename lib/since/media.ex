defmodule Since.Media do
  @moduledoc "Functions to interact with user generated and static media on AWS S3"
  alias __MODULE__.{Static, Client}

  # TODO use mox in test env

  @doc """
  Bucket for user-generated content. Like photos.
  """
  def user_bucket, do: bucket(:user_bucket)

  defp user_cdn_endpoint, do: cdn_endpoint(:user_cdn)

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
    Application.fetch_env!(:since, __MODULE__)[name]
  end

  defp bucket(name) do
    Application.fetch_env!(:since, __MODULE__)[name]
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
    url =
      S3.sign(
        s3_config(
          method: method,
          url: s3_url(bucket),
          path: key,
          query: %{"X-Amz-Expires" => 86400}
        )
      )

    URI.to_string(url)
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

  # cdn -> imgproxy -> cdn -> s3
  def user_imgproxy_cdn_url(s3_key, requested_width, opts) do
    user_imgproxy_cdn_url(user_cdn_url(s3_key), requested_width, opts)
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

  # TODO make s3 bucket private
  def user_cdn_url(s3_key) do
    Path.join([user_cdn_endpoint(), s3_key])
  end

  @doc false
  def s3_url(bucket) do
    # TODO #{bucket}.s3.#{region}.amazonaws.com
    "https://#{bucket}.s3.amazonaws.com"
  end

  defp s3_config do
    Application.fetch_env!(:since, :s3)
  end

  defp s3_config(options) do
    Keyword.merge(s3_config(), options)
  end

  @doc false
  def s3_request(opts) do
    method = Keyword.fetch!(opts, :method)
    {uri, headers, body} = S3.build(s3_config(opts))
    req = Finch.build(method, uri, headers, body)
    Finch.request!(req, Since.Finch)
  end

  def user_file_exists?(key) do
    %Finch.Response{status: status} =
      s3_request(
        method: :head,
        url: s3_url(user_bucket()),
        path: key
      )

    case status do
      200 -> true
      404 -> false
    end
  end

  def sign_form_upload(bucket \\ user_bucket(), opts) do
    config = Map.new(s3_config())

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
    result = s3_request(method: :delete, url: s3_url(static_bucket()), path: key)
    Static.notify_s3_updated()
    result
  end

  def rename_static_file(from_key, to_key) do
    bucket = static_bucket()

    # https://docs.aws.amazon.com/AmazonS3/latest/API/API_CopyObject.html
    %Finch.Response{status: 200} =
      copy_result =
      s3_request(
        method: :put,
        url: s3_url(bucket),
        path: to_key,
        headers: %{"x-amz-copy-source" => "/#{bucket}/#{from_key}"}
      )

    %Finch.Response{status: 204} =
      delete_result =
      s3_request(
        method: :delete,
        url: s3_url(bucket),
        path: from_key
      )

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

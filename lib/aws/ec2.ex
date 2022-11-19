defmodule AWS.EC2 do
  alias AWS.Request

  def metadata do
    %{
      abbreviation: nil,
      api_version: "2006-03-01",
      content_type: "text/xml",
      credential_scope: nil,
      endpoint_prefix: "s3",
      global?: false,
      protocol: "rest-xml",
      service_id: "S3",
      signature_version: "s3",
      signing_name: "s3",
      target_prefix: nil
    }
  end

  # https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadObject.html
  def head_object(client, bucket, key, input, options \\ []) do
    url_path = "/#{AWS.Util.encode_uri(bucket)}/#{AWS.Util.encode_multi_segment_uri(key)}"

    {headers, input} =
      [
        {"ChecksumMode", "x-amz-checksum-mode"},
        {"ExpectedBucketOwner", "x-amz-expected-bucket-owner"},
        {"IfMatch", "If-Match"},
        {"IfModifiedSince", "If-Modified-Since"},
        {"IfNoneMatch", "If-None-Match"},
        {"IfUnmodifiedSince", "If-Unmodified-Since"},
        {"Range", "Range"},
        {"RequestPayer", "x-amz-request-payer"},
        {"SSECustomerAlgorithm", "x-amz-server-side-encryption-customer-algorithm"},
        {"SSECustomerKey", "x-amz-server-side-encryption-customer-key"},
        {"SSECustomerKeyMD5", "x-amz-server-side-encryption-customer-key-MD5"}
      ]
      |> Request.build_params(input)

    {query_params, input} =
      [
        {"PartNumber", "partNumber"},
        {"VersionId", "versionId"}
      ]
      |> Request.build_params(input)

    options =
      Keyword.put(
        options,
        :response_header_parameters,
        [
          {"x-amz-checksum-crc32c", "ChecksumCRC32C"},
          {"x-amz-delete-marker", "DeleteMarker"},
          {"x-amz-object-lock-retain-until-date", "ObjectLockRetainUntilDate"},
          {"x-amz-restore", "Restore"},
          {"x-amz-server-side-encryption-bucket-key-enabled", "BucketKeyEnabled"},
          {"Content-Type", "ContentType"},
          {"x-amz-server-side-encryption-customer-key-MD5", "SSECustomerKeyMD5"},
          {"x-amz-object-lock-legal-hold", "ObjectLockLegalHoldStatus"},
          {"x-amz-version-id", "VersionId"},
          {"accept-ranges", "AcceptRanges"},
          {"x-amz-website-redirect-location", "WebsiteRedirectLocation"},
          {"Content-Language", "ContentLanguage"},
          {"x-amz-server-side-encryption-customer-algorithm", "SSECustomerAlgorithm"},
          {"Content-Encoding", "ContentEncoding"},
          {"x-amz-checksum-sha256", "ChecksumSHA256"},
          {"ETag", "ETag"},
          {"x-amz-archive-status", "ArchiveStatus"},
          {"Last-Modified", "LastModified"},
          {"Expires", "Expires"},
          {"x-amz-expiration", "Expiration"},
          {"x-amz-replication-status", "ReplicationStatus"},
          {"Cache-Control", "CacheControl"},
          {"x-amz-storage-class", "StorageClass"},
          {"x-amz-missing-meta", "MissingMeta"},
          {"Content-Length", "ContentLength"},
          {"x-amz-object-lock-mode", "ObjectLockMode"},
          {"Content-Disposition", "ContentDisposition"},
          {"x-amz-request-charged", "RequestCharged"},
          {"x-amz-server-side-encryption", "ServerSideEncryption"},
          {"x-amz-mp-parts-count", "PartsCount"},
          {"x-amz-server-side-encryption-aws-kms-key-id", "SSEKMSKeyId"},
          {"x-amz-checksum-crc32", "ChecksumCRC32"},
          {"x-amz-checksum-sha1", "ChecksumSHA1"}
        ]
      )

    meta = metadata()

    Request.request_rest(
      client,
      meta,
      :head,
      url_path,
      query_params,
      headers,
      input,
      options,
      nil
    )
  end

  # https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListObjectsV2.html
  def list_objects_v2(
        client,
        bucket,
        continuation_token \\ nil,
        delimiter \\ nil,
        encoding_type \\ nil,
        fetch_owner \\ nil,
        max_keys \\ nil,
        prefix \\ nil,
        start_after \\ nil,
        expected_bucket_owner \\ nil,
        request_payer \\ nil,
        options \\ []
      ) do
    url_path = "/#{AWS.Util.encode_uri(bucket)}?list-type=2"
    headers = []

    headers =
      if !is_nil(expected_bucket_owner) do
        [{"x-amz-expected-bucket-owner", expected_bucket_owner} | headers]
      else
        headers
      end

    headers =
      if !is_nil(request_payer) do
        [{"x-amz-request-payer", request_payer} | headers]
      else
        headers
      end

    query_params = []

    query_params =
      if !is_nil(start_after) do
        [{"start-after", start_after} | query_params]
      else
        query_params
      end

    query_params =
      if !is_nil(prefix) do
        [{"prefix", prefix} | query_params]
      else
        query_params
      end

    query_params =
      if !is_nil(max_keys) do
        [{"max-keys", max_keys} | query_params]
      else
        query_params
      end

    query_params =
      if !is_nil(fetch_owner) do
        [{"fetch-owner", fetch_owner} | query_params]
      else
        query_params
      end

    query_params =
      if !is_nil(encoding_type) do
        [{"encoding-type", encoding_type} | query_params]
      else
        query_params
      end

    query_params =
      if !is_nil(delimiter) do
        [{"delimiter", delimiter} | query_params]
      else
        query_params
      end

    query_params =
      if !is_nil(continuation_token) do
        [{"continuation-token", continuation_token} | query_params]
      else
        query_params
      end

    meta = metadata()

    Request.request_rest(client, meta, :get, url_path, query_params, headers, nil, options, nil)
  end
end

defmodule T.Voicemail do
  @moduledoc "Manages voice-mail between matched users"
  alias T.Media

  def audio_s3_url do
    Media.user_s3_url()
  end

  def audio_upload_form(content_type) do
    Media.sign_form_upload(
      key: Ecto.UUID.generate(),
      content_type: content_type,
      # 50 MB
      max_file_size: 50_000_000,
      expires_in: :timer.hours(1)
    )
  end
end

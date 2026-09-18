require "rack/test"

module MediaCrudUploads
  def sample_image
    Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/media_crud_sample.png").to_s, "image/png"
    )
  end

  def sample_music
    Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/media_crud_sample.wav").to_s, "audio/wav"
    )
  end

  def valid_media_attributes
    {
      title: "サンプル作品", creator: "テスト作者", description: "画像と音楽のテストです。",
      image_upload: sample_image, music_upload: sample_music
    }
  end
end

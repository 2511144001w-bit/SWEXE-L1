class MediaItem < ApplicationRecord
  attr_accessor :upload

  # 画面・コントローラーで使っている名前を、実際の画像用の項目に対応させる
  alias_attribute :file_name, :image_name
  alias_attribute :content_type, :image_content_type
  alias_attribute :file_data, :image_data

  before_save :store_file, if: -> { upload.present? }

  private

  def store_file
    self.image_name = File.basename(upload.original_filename)
    self.image_content_type = upload.content_type
    self.image_data = upload.read
    self.upload = nil
  end
end

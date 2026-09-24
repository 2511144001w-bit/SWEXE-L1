class MediaItem < ApplicationRecord
  attr_accessor :upload

  alias_attribute :file_name, :image_name
  alias_attribute :content_type, :image_content_type
  alias_attribute :file_data, :image_data

  validates :title, :creator, presence: { message: "を入力してください" }
  validate :upload_is_valid, if: -> { upload.present? }

  before_save :store_file, if: -> { upload.present? }

  private

  def upload_is_valid
    return if upload.respond_to?(:original_filename) && upload.respond_to?(:content_type) &&
              upload.respond_to?(:read) && upload.original_filename.to_s.present?

    errors.add(:upload, "が無効です")
  end

  def store_file
    self.image_name = File.basename(upload.original_filename.to_s.tr("\\", "/"))
    self.image_content_type = upload.content_type
    self.image_data = upload.read
    self.upload = nil
  rescue IOError, SystemCallError
    errors.add(:upload, "を読み込めませんでした")
    throw :abort
  end
end

require "marcel"

class MediaItem < ApplicationRecord
  IMAGE_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  MUSIC_TYPES = %w[audio/mpeg audio/wav audio/x-wav audio/vnd.wave].freeze
  IMAGE_LIMIT = 5.megabytes
  MUSIC_LIMIT = 10.megabytes

  
  attr_accessor :image_upload, :music_upload, :remove_image, :remove_music

  before_validation :apply_file_changes
  after_save :clear_upload_inputs

  validates :title, :creator, presence: { message: "を入力してください。" }
  validates :title, :creator,
            length: { maximum: 100, message: "は100文字以内で入力してください。" }
  validates :description,
            length: { maximum: 2000, message: "は2000文字以内で入力してください。" }
  validate :at_least_one_file

  def image_attached?
    image_name.present?
  end

  def music_attached?
    music_name.present?
  end

  private

  def apply_file_changes
    apply_upload(:image, IMAGE_TYPES, IMAGE_LIMIT, "画像")
    apply_upload(:music, MUSIC_TYPES, MUSIC_LIMIT, "音楽")
  end

  def apply_upload(kind, allowed_types, limit, label)
    upload = public_send("#{kind}_upload")

    # 削除チェックと新しいファイルを同時に指定した場合は、新しいファイルを優先。
    if upload.blank?
      if ActiveModel::Type::Boolean.new.cast(public_send("remove_#{kind}"))
        public_send("#{kind}_name=", nil)
        public_send("#{kind}_content_type=", nil)
        public_send("#{kind}_data=", nil)
      end
      return
    end

    unless upload.respond_to?(:tempfile) && upload.respond_to?(:original_filename)
      errors.add(:base, "#{label}にはファイルを選択してください。")
      return
    end

    if upload.size.zero? || upload.size > limit
      errors.add(:base, "#{label}は空でない、#{limit / 1.megabyte}MB以下のファイルにしてください。")
      return
    end

    # 拡張子やブラウザーが申告する種類だけを信用せず、本体から種類を調べる
    upload.tempfile.rewind
    content_type = Marcel::MimeType.for(upload.tempfile)
    unless allowed_types.include?(content_type)
      formats = kind == :image ? "PNG・JPEG・GIF・WebP" : "MP3・WAV"
      errors.add(:base, "#{label}は#{formats}形式にしてください。")
      return
    end

    upload.tempfile.rewind
    data = upload.tempfile.read(limit + 1)
    if data.nil? || data.empty? || data.bytesize > limit
      errors.add(:base, "#{label}のファイルサイズを確認してください。")
      return
    end

    # ファイル名は表示用。
    name = File.basename(upload.original_filename.to_s.tr("\\", "/"))
               .delete("\x00").gsub(/[\r\n]/, "_").first(200)
    name = kind.to_s if name.blank?
    public_send("#{kind}_name=", name)
    public_send("#{kind}_content_type=", content_type)
    public_send("#{kind}_data=", data)
  end

  def at_least_one_file
    if image_data.blank? && music_data.blank?
      errors.add(:base, "画像または音楽を少なくとも1つ登録してください。")
    end
  end

  def clear_upload_inputs
    self.image_upload = self.music_upload = nil
    self.remove_image = self.remove_music = nil
  end
end

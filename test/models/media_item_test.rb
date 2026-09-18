require "test_helper"
require_relative "../support/media_crud_uploads"

class MediaItemTest < ActiveSupport::TestCase
  include MediaCrudUploads

  test "画像と音楽を同じモデルに保存できる" do
    item = MediaItem.create!(valid_media_attributes)
    item.reload
    assert_equal "サンプル作品", item.title
    assert item.image_data.present?
    assert item.music_data.present?
    assert_equal "image/png", item.image_content_type
    assert_includes MediaItem::MUSIC_TYPES, item.music_content_type
  end

  test "画像のみでも登録できる" do
    item = MediaItem.new(title: "画像", creator: "作者", image_upload: sample_image)
    assert item.save, item.errors.full_messages.join(" / ")
    assert_not item.music_attached?
  end

  test "音楽のみでも登録できる" do
    item = MediaItem.new(title: "音楽", creator: "作者", music_upload: sample_music)
    assert item.save, item.errors.full_messages.join(" / ")
    assert_not item.image_attached?
  end

  test "タイトルと作者は必須" do
    item = MediaItem.new(image_upload: sample_image)
    assert_not item.valid?
    assert item.errors[:title].present?
    assert item.errors[:creator].present?
  end

  test "文字数制限を超えた入力を拒否する" do
    item = MediaItem.new(valid_media_attributes.merge(title: "あ" * 101, description: "あ" * 2001))
    assert_not item.valid?
    assert item.errors[:title].present?
    assert item.errors[:description].present?
  end

  test "ファイルが両方ない場合は保存しない" do
    item = MediaItem.new(title: "空の作品", creator: "作者")
    assert_not item.save
    assert_includes item.errors[:base], "画像または音楽を少なくとも1つ登録してください。"
  end

  test "画像欄に音楽を渡すと保存しない" do
    item = MediaItem.new(title: "形式違い", creator: "作者", image_upload: sample_music)
    assert_not item.save
    assert item.errors[:base].any? { |text| text.include?("PNG") }
  end

  test "大きすぎるファイルを拒否する" do
    upload = sample_image
    upload.define_singleton_method(:size) { MediaItem::IMAGE_LIMIT + 1 }
    item = MediaItem.new(title: "サイズ違い", creator: "作者", image_upload: upload)
    assert_not item.save
    assert item.errors[:base].any? { |text| text.include?("5MB") }
  end

  test "空ファイルを拒否する" do
    upload = sample_image
    upload.tempfile.truncate(0)
    item = MediaItem.new(title: "空ファイル", creator: "作者", image_upload: upload)
    assert_not item.save
  end

  test "文字列をアップロードとして渡しても例外にならない" do
    item = MediaItem.new(title: "不正な入力", creator: "作者", image_upload: "not a file")
    assert_not item.save
  end

  test "テキストの更新だけならファイルを保持する" do
    item = MediaItem.create!(valid_media_attributes)
    old_image, old_music = item.image_data, item.music_data
    assert item.update(title: "変更後")
    item.reload
    assert_equal old_image, item.image_data
    assert_equal old_music, item.music_data
  end

  test "片方だけのファイルを削除できる" do
    item = MediaItem.create!(valid_media_attributes)
    assert item.update(remove_image: "1")
    item.reload
    assert_nil item.image_name
    assert_nil item.image_data
    assert item.music_data.present?
  end

  test "両方のファイル削除は拒否し保存済みデータを維持する" do
    item = MediaItem.create!(valid_media_attributes)
    assert_not item.update(remove_image: "1", remove_music: "1")
    item.reload
    assert item.image_data.present?
    assert item.music_data.present?
  end

  test "削除チェックと新規ファイルを同時に指定したら新規ファイルを優先する" do
    item = MediaItem.create!(valid_media_attributes)
    assert item.update(remove_image: "1", image_upload: sample_image)
    assert item.reload.image_data.present?
  end

  test "作品の削除でファイル本体もデータベースから削除される" do
    item = MediaItem.create!(valid_media_attributes)
    id = item.id
    assert_difference("MediaItem.count", -1) { item.destroy! }
    assert_not MediaItem.exists?(id)
  end
end

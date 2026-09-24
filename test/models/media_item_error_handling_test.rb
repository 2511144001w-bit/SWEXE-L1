require "test_helper"

class MediaItemErrorHandlingTest < ActiveSupport::TestCase
  test "unreadable upload does not save the record" do
    upload = Object.new
    upload.define_singleton_method(:original_filename) { "image.png" }
    upload.define_singleton_method(:content_type) { "image/png" }
    upload.define_singleton_method(:read) { raise IOError }

    item = MediaItem.new(title: "画像", creator: "作者", upload: upload)

    assert_not item.save
    assert item.errors[:upload].present?
    assert_not item.persisted?
  end
end

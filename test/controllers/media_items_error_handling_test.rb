require "test_helper"

class MediaItemsErrorHandlingTest < ActionDispatch::IntegrationTest
  setup do
    @item = MediaItem.create!(title: "既存の作品", creator: "作者")
  end

  test "required fields return validation errors instead of an exception" do
    assert_no_difference("MediaItem.count") do
      post media_items_path, params: { media_item: { title: "", creator: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "invalid upload returns a validation error" do
    assert_no_difference("MediaItem.count") do
      post media_items_path, params: { media_item: { title: "新規", creator: "作者", upload: "invalid" } }
    end

    assert_response :unprocessable_entity
  end

  test "invalid update leaves the saved item unchanged" do
    patch media_item_path(@item), params: { media_item: { title: "" } }

    assert_response :unprocessable_entity
    assert_equal "既存の作品", @item.reload.title
  end

  test "missing image data returns not found" do
    get media_item_path(@item, file: "1")

    assert_response :not_found
  end

  test "unknown file request returns not found" do
    get media_item_path(@item, file: "unknown")

    assert_response :not_found
  end

  test "missing item shows a Japanese not found page" do
    get media_item_path(id: 999_999)

    assert_response :not_found
    assert_select "html[lang='ja']"
    assert_select "h1", "ページが見つかりません"
  end

  test "missing form parameters show a Japanese error page" do
    post media_items_path

    assert_response :unprocessable_entity
    assert_select "html[lang='ja']"
    assert_select "h1", "操作を完了できませんでした"
  end
end

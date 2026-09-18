require "test_helper"
require_relative "../support/media_crud_uploads"

class MediaItemsControllerTest < ActionDispatch::IntegrationTest
  include MediaCrudUploads

  setup do
    @item = MediaItem.create!(valid_media_attributes)
  end

  test "resourcesの7機能にルーティングされる" do
    assert_routing({ path: "/media_items", method: :get },
                   { controller: "media_items", action: "index" })
    assert_routing({ path: "/media_items/new", method: :get },
                   { controller: "media_items", action: "new" })
    assert_routing({ path: "/media_items", method: :post },
                   { controller: "media_items", action: "create" })
    assert_routing({ path: "/media_items/1", method: :get },
                   { controller: "media_items", action: "show", id: "1" })
    assert_routing({ path: "/media_items/1/edit", method: :get },
                   { controller: "media_items", action: "edit", id: "1" })
    %i[patch put].each do |method|
      assert_routing({ path: "/media_items/1", method: method },
                     { controller: "media_items", action: "update", id: "1" })
    end
    assert_routing({ path: "/media_items/1", method: :delete },
                   { controller: "media_items", action: "destroy", id: "1" })
  end

  test "index 一覧を表示できる" do
    get media_items_path
    assert_response :success
    assert_select "h1", "作品一覧"
    assert_select "td", text: @item.title
  end

  test "new ファイル付き新規登録フォームを表示できる" do
    get new_media_item_path
    assert_response :success
    assert_select 'form[enctype="multipart/form-data"]'
    assert_select 'input[type="file"]', count: 2
  end

  test "create 画像と音楽を登録できる" do
    assert_difference("MediaItem.count", 1) do
      post media_items_path, params: { media_item: valid_media_attributes }
    end
    assert_response :see_other
    assert_redirected_to media_item_path(MediaItem.order(:id).last)
    follow_redirect!
    assert_select "p[role='status']", "登録しました。"
  end

  test "create 入力エラーでは登録せず新規画面に戻る" do
    assert_no_difference("MediaItem.count") do
      post media_items_path, params: { media_item: { title: "", creator: "" } }
    end
    assert_response 422
    assert_select '[role="alert"]'
  end

  test "show 画像と音楽プレーヤーを表示できる" do
    get media_item_path(@item)
    assert_response :success
    assert_select "h1", @item.title
    assert_select "img.preview-image"
    assert_select "audio[controls] source"
    assert_select "form input[name='_method'][value='delete']"
  end

  test "show 画像本体を取得できる" do
    get media_item_path(@item, file: "image")
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal @item.image_data, response.body.b
  end

  test "show 音楽本体を取得できる" do
    get media_item_path(@item, file: "music")
    assert_response :success
    assert_includes MediaItem::MUSIC_TYPES, response.media_type
    assert_equal @item.music_data, response.body.b
  end

  test "show 音楽の一部を取得できる" do
    get media_item_path(@item, file: "music"), headers: { "Range" => "bytes=0-15" }
    assert_response :partial_content
    assert_equal @item.music_data.byteslice(0, 16), response.body.b
    assert_equal "bytes 0-15/#{@item.music_data.bytesize}", response.headers["Content-Range"]
  end

  test "show 末尾範囲と範囲外指定を処理できる" do
    get media_item_path(@item, file: "music"), headers: { "Range" => "bytes=-10" }
    assert_response :partial_content
    assert_equal @item.music_data.byteslice(-10, 10), response.body.b
    get media_item_path(@item, file: "music"), headers: { "Range" => "bytes=999999999-" }
    assert_response :range_not_satisfiable
  end

  test "show 不明なファイル指定は404" do
    get media_item_path(@item, file: "secret")
    assert_response :not_found
  end

  test "show 登録していないファイルは404" do
    @item.update!(remove_image: "1")
    get media_item_path(@item, file: "image")
    assert_response :not_found
  end

  test "edit 編集フォームを表示できる" do
    get edit_media_item_path(@item)
    assert_response :success
    assert_select "h1", "作品の編集"
    assert_select 'input[name="media_item[title]"]' do |elements|
      assert_equal @item.title, elements.first["value"]
    end
  end

  test "update タイトルを更新しファイルは保持する" do
    old_music = @item.music_data
    patch media_item_path(@item), params: { media_item: { title: "更新した作品" } }
    assert_response :see_other
    assert_equal "更新した作品", @item.reload.title
    assert_equal old_music, @item.music_data
  end

  test "update 画像を差し替えられる" do
    file = sample_image
    file.define_singleton_method(:original_filename) { "replacement.png" }
    patch media_item_path(@item), params: { media_item: { image_upload: file } }
    assert_response :see_other
    assert_equal "replacement.png", @item.reload.image_name
  end

  test "update 入力エラーでは保存しない" do
    old_title = @item.title
    patch media_item_path(@item), params: { media_item: { title: "" } }
    assert_response 422
    assert_equal old_title, @item.reload.title
    assert_select '[role="alert"]'
  end

  test "update 音楽のみ削除できる" do
    patch media_item_path(@item), params: { media_item: { remove_music: "1" } }
    assert_response :see_other
    assert_nil @item.reload.music_data
    assert @item.image_data.present?
  end

  test "destroy 作品を削除できる" do
    assert_difference("MediaItem.count", -1) { delete media_item_path(@item) }
    assert_redirected_to media_items_path
    follow_redirect!
    assert_select "p[role='status']", "削除しました。"
  end

  test "HTML入力をそのまま実行せずエスケープする" do
    @item.update!(title: "<script>alert(1)</script>", description: "<script>alert(2)</script>")
    get media_item_path(@item)
    assert_response :success
    assert_select "script", count: 0
    assert_includes response.body, "&lt;script&gt;"
  end

  test "保存対象外のカラムをフォームから変更できない" do
    patch media_item_path(@item), params: {
      media_item: { title: "許可した項目", image_content_type: "text/html", image_data: "fake" }
    }
    assert_response :see_other
    assert_equal "image/png", @item.reload.image_content_type
    assert_not_equal "fake", @item.image_data
  end
end

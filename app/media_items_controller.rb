class MediaItemsController < ApplicationController
  layout "media_crud"
  before_action :set_media_item, only: %i[show edit update destroy]

  # 1. 一覧表示（大きい画像・音楽データは一覧のSQLでは読み込みません）
  def index
    @media_items = MediaItem.select(
      :id, :title, :creator, :image_name, :music_name, :created_at, :updated_at
    ).order(id: :desc)
  end

  # 2. 新規登録画面
  def new
    @media_item = MediaItem.new
  end

  # 3. 登録処理
  def create
    @media_item = MediaItem.new(media_item_params)
    if @media_item.save
      redirect_to @media_item, notice: "登録しました。", status: :see_other
    else
      render :new, status: 422
    end
  end

  # 4. 詳細表示
  # ?file=image / ?file=music の場合もこの show を使うため、追加アクションは不要。
  def show
    case params[:file]
    when nil
      # 通常は show.html.erb を表示します。
    when "image"
      send_media(:image)
    when "music"
      send_media(:music)
    else
      head :not_found
    end
  end

  # 5. 編集画面
  def edit
  end

  # 6. 更新処理
  def update
    if @media_item.update(media_item_params)
      redirect_to @media_item, notice: "更新しました。", status: :see_other
    else
      render :edit, status: 422
    end
  end

  # 7. 削除処理（画像・音楽本体も同じレコードなので一緒に削除されます）
  def destroy
    @media_item.destroy!
    redirect_to media_items_path, notice: "削除しました。", status: :see_other
  end

  private

  def set_media_item
    @media_item = MediaItem.find(params[:id])
  end

  def media_item_params
    # Rails 8 の Strong Parameters。保存を許すフォーム項目だけを列挙します。
    params.expect(media_item: [
      :title, :creator, :description,
      :image_upload, :music_upload, :remove_image, :remove_music
    ])
  end

  def send_media(kind)
    data = @media_item.public_send("#{kind}_data")
    return head(:not_found) if data.blank?

    response.headers["Accept-Ranges"] = "bytes"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Cache-Control"] = "private, no-store"
    range = requested_range(data.bytesize)

    if range == :unsatisfiable
      response.headers["Content-Range"] = "bytes */#{data.bytesize}"
      return head(:range_not_satisfiable)
    end

    options = {
      filename: @media_item.public_send("#{kind}_name"),
      type: @media_item.public_send("#{kind}_content_type"),
      disposition: "inline"
    }
    if range
      response.headers["Content-Range"] = "bytes #{range.begin}-#{range.end}/#{data.bytesize}"
      send_data data.byteslice(range), **options, status: :partial_content
    else
      send_data data, **options
    end
  end

  # 音楽プレーヤーのシーク用に、単一の byte Range 要求に対応します。
  # 複数範囲・不明な形式は範囲指定を無視して全体を返します。
  def requested_range(size)
    return nil if request.headers["If-Range"].present?

    match = /\Abytes=(\d*)-(\d*)\z/.match(request.headers["Range"].to_s)
    return nil unless match

    first_text, last_text = match.captures
    return :unsatisfiable if first_text.empty? && last_text.empty?

    if first_text.empty?
      suffix_length = last_text.to_i
      return :unsatisfiable if suffix_length.zero?
      first = [size - suffix_length, 0].max
      last = size - 1
    else
      first = first_text.to_i
      last = last_text.empty? ? size - 1 : [last_text.to_i, size - 1].min
    end
    return :unsatisfiable if first >= size || last < first

    first..last
  end
end

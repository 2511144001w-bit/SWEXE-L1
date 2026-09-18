class MediaItemsController < ApplicationController
  layout "media_library"
  before_action :set_media_item, only: %i[show edit update destroy]

  def index
    @media_items = MediaItem.order(id: :desc)
  end

  def new
    @media_item = MediaItem.new
  end

  def create
    @media_item = MediaItem.new(media_item_params)
    @media_item.save!
    redirect_to @media_item, status: :see_other
  end

  def show
    # 詳細ページに埋め込む画像も、このshowアクションから返す。
    if params[:file] == "1"
      response.headers["Content-Security-Policy"] = "sandbox; default-src 'none'"
      send_data @media_item.file_data,
                filename: @media_item.file_name,
                type: @media_item.content_type,
                disposition: "inline"
    end
  end

  def edit
  end

  def update
    @media_item.update!(media_item_params)
    redirect_to @media_item, status: :see_other
  end

  def destroy
    @media_item.destroy!
    redirect_to media_items_path, status: :see_other
  end

  private

  def set_media_item
    @media_item = MediaItem.find(params[:id])
  end

  def media_item_params
    params.require(:media_item).permit(:title, :creator, :description, :upload)
  end
end

class MediaItemsController < ApplicationController
  layout "media_library"
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_invalid_request
  before_action :set_media_item, only: %i[show edit update destroy]

  def index
    @media_items = MediaItem.order(id: :desc)
  end

  def new
    @media_item = MediaItem.new
  end

  def create
    @media_item = MediaItem.new(media_item_params)
    if @media_item.save
      # 追加
      redirect_to media_item_path(@media_item), notice: "登録しました。", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    return if params[:file].blank?
    return head :not_found unless params[:file] == "1" && @media_item.file_data.present?

    response.headers["Content-Security-Policy"] = "sandbox; default-src 'none'"
    send_data @media_item.file_data,
              filename: @media_item.file_name,
              type: @media_item.content_type,
              disposition: "inline"
  end

  def edit
  end

  def update
    if @media_item.update(media_item_params)
      # 追加
      redirect_to media_item_path(@media_item), notice: "更新しました。", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @media_item.destroy
      redirect_to media_items_path, notice: "削除しました。", status: :see_other
    else
      # 追加
      redirect_to media_item_path(@media_item), alert: "削除できませんでした。", status: :see_other
    end
  end

  private

  def render_not_found
    render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
  end

  def render_invalid_request
    render file: Rails.root.join("public/422.html"), status: :unprocessable_entity, layout: false
  end

  def set_media_item
    @media_item = MediaItem.find(params[:id])
  end

  def media_item_params
    params.require(:media_item).permit(:title, :creator, :description, :upload)
  end
end

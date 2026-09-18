#!/usr/bin/env ruby
require "json"
require "fileutils"

unless File.file?("Gemfile") && File.file?("app/models/media_item.rb") && File.file?("config/routes.rb")
  abort "導入済みのRailsプロジェクトで、Gemfileと同じ階層から実行してください。"
end

files = JSON.parse(DATA.read)
backup = "tmp/images_only_backup/#{Time.now.utc.strftime('%Y%m%d_%H%M%S_%6N')}"
files.each do |path, content|
  next if File.file?(path) && File.binread(path) == content.b

  if File.file?(path)
    FileUtils.mkdir_p(File.dirname("#{backup}/#{path}"))
    FileUtils.cp(path, "#{backup}/#{path}")
  end
  FileUtils.mkdir_p(File.dirname(path))
  File.binwrite(path, content)
  puts "変更: #{path}"
end

puts "画像専用への変更が完了しました。"
puts "DBは変更していません。bin/rails db:migrate は不要です。"
puts "サーバーを再起動し、/media_items を開いてください。"
__END__
{
  "app/models/media_item.rb": "class MediaItem < ApplicationRecord\n  attr_accessor :upload\n\n  # 画像を選び直していないときは、保存済みの画像をそのまま残す。\n  before_save :store_file, if: -> { upload.present? }\n\n  private\n\n  def store_file\n    self.file_name = File.basename(upload.original_filename)\n    self.content_type = upload.content_type\n    self.file_data = upload.read\n    self.upload = nil\n  end\nend\n",
  "app/controllers/media_items_controller.rb": "class MediaItemsController < ApplicationController\n  layout \"media_library\"\n  before_action :set_media_item, only: %i[show edit update destroy]\n\n  def index\n    @media_items = MediaItem.where(media_type: \"image\").order(id: :desc)\n  end\n\n  def new\n    @media_item = MediaItem.new\n  end\n\n  def create\n    @media_item = MediaItem.new(media_item_params)\n    @media_item.media_type = \"image\"\n    @media_item.save!\n    redirect_to @media_item, status: :see_other\n  end\n\n  def show\n    # 詳細ページに埋め込む画像も、このshowアクションから返す。\n    if params[:file] == \"1\"\n      response.headers[\"Content-Security-Policy\"] = \"sandbox; default-src 'none'\"\n      send_data @media_item.file_data,\n                filename: @media_item.file_name,\n                type: @media_item.content_type,\n                disposition: \"inline\"\n    end\n  end\n\n  def edit\n  end\n\n  def update\n    @media_item.update!(media_item_params)\n    redirect_to @media_item, status: :see_other\n  end\n\n  def destroy\n    @media_item.destroy!\n    redirect_to media_items_path, status: :see_other\n  end\n\n  private\n\n  def set_media_item\n    @media_item = MediaItem.where(media_type: \"image\").find(params[:id])\n  end\n\n  def media_item_params\n    params.require(:media_item).permit(:title, :creator, :description, :upload)\n  end\nend\n",
  "app/views/media_items/index.html.erb": "<h1>画像一覧</h1>\n<p><%= link_to \"新規登録\", new_media_item_path %></p>\n\n<table>\n  <thead>\n    <tr>\n      <th>タイトル</th>\n      <th>作者</th>\n      <th>操作</th>\n    </tr>\n  </thead>\n  <tbody>\n    <% @media_items.each do |item| %>\n      <tr>\n        <td><%= item.title %></td>\n        <td><%= item.creator %></td>\n        <td>\n          <%= link_to \"詳細\", media_item_path(item) %>\n          <%= link_to \"編集\", edit_media_item_path(item) %>\n          <%= button_to \"削除\", media_item_path(item), method: :delete %>\n        </td>\n      </tr>\n    <% end %>\n  </tbody>\n</table>\n",
  "app/views/media_items/_form.html.erb": "<%= form_with model: media_item, local: true, multipart: true, data: { turbo: false } do |form| %>\n  <p>\n    <%= form.label :title, \"タイトル\" %>\n    <%= form.text_field :title %>\n  </p>\n  <p>\n    <%= form.label :creator, \"作者\" %>\n    <%= form.text_field :creator %>\n  </p>\n  <p>\n    <%= form.label :description, \"説明\" %>\n    <%= form.text_area :description, rows: 4 %>\n  </p>\n  <p>\n    <%= form.label :upload, \"画像ファイル\" %>\n    <%= form.file_field :upload, accept: \"image/*\" %>\n  </p>\n  <p>編集時に画像を選ばなければ、元の画像を残します。</p>\n  <%= form.submit(media_item.persisted? ? \"更新する\" : \"登録する\") %>\n<% end %>\n",
  "app/views/media_items/new.html.erb": "<h1>画像の新規登録</h1>\n<%= render \"form\", media_item: @media_item %>\n<p><%= link_to \"一覧に戻る\", media_items_path %></p>\n",
  "app/views/media_items/edit.html.erb": "<h1>画像の編集</h1>\n<%= render \"form\", media_item: @media_item %>\n<p>\n  <%= link_to \"詳細に戻る\", media_item_path(@media_item) %>\n  <%= link_to \"一覧に戻る\", media_items_path %>\n</p>\n",
  "app/views/media_items/show.html.erb": "<h1><%= @media_item.title %></h1>\n<p>作者：<%= @media_item.creator %></p>\n<p>説明：</p>\n<p class=\"description\"><%= @media_item.description %></p>\n<p>ファイル名：<%= @media_item.file_name %></p>\n\n<% if @media_item.file_data.present? %>\n  <%= image_tag media_item_path(@media_item, file: \"1\"), alt: @media_item.title, class: \"preview\" %>\n<% end %>\n\n<p>\n  <%= link_to \"編集\", edit_media_item_path(@media_item) %>\n  <%= link_to \"一覧に戻る\", media_items_path %>\n</p>\n<%= button_to \"削除\", media_item_path(@media_item), method: :delete %>\n",
  "app/views/layouts/media_library.html.erb": "<!DOCTYPE html>\n<html lang=\"ja\">\n  <head>\n    <meta charset=\"utf-8\">\n    <meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n    <title>画像管理</title>\n    <%= csrf_meta_tags %>\n    <%= csp_meta_tag %>\n    <%= stylesheet_link_tag \"media_library\" %>\n  </head>\n  <body>\n    <%= yield %>\n  </body>\n</html>\n",
  "app/assets/stylesheets/media_library.css": "body { max-width: 900px; margin: 24px auto; padding: 0 16px; font-family: sans-serif; line-height: 1.6; }\ntable { border-collapse: collapse; width: 100%; }\nth, td { border: 1px solid #ccc; padding: 8px; text-align: left; overflow-wrap: anywhere; }\nlabel { display: block; }\ninput[type=\"text\"], textarea { width: 100%; max-width: 500px; box-sizing: border-box; }\ninput, textarea, button { font: inherit; }\n.button_to { display: inline; margin-left: 8px; }\n.description { white-space: pre-wrap; overflow-wrap: anywhere; }\n.preview { display: block; max-width: 100%; max-height: 500px; }\n"
}

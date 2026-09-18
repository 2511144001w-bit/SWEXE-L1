class CreateMediaItems < ActiveRecord::Migration[8.1]
  def change
    create_table :media_items do |t|
      t.string :title, null: false
      t.string :creator, null: false
      t.text :description
      t.string :image_name
      t.string :image_content_type
      t.binary :image_data
      t.string :music_name
      t.string :music_content_type
      t.binary :music_data
      t.timestamps
    end
  end
end

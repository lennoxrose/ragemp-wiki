class CreateActivityTables < ActiveRecord::Migration[8.0]
  def change
    create_table :page_views do |t|
      t.references :page, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.datetime :created_at, null: false
    end
    add_index :page_views, :created_at

    create_table :search_logs do |t|
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :query, null: false
      t.integer :results_count, null: false, default: 0
      t.datetime :created_at, null: false
    end
    add_index :search_logs, :created_at

    create_table :topics do |t|
      t.references :page, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :title, null: false
      t.string :status, null: false, default: "open"
      t.boolean :pinned, null: false, default: false
      t.integer :posts_count, null: false, default: 0
      t.datetime :last_activity_at, null: false
      t.timestamps
    end

    create_table :posts do |t|
      t.references :topic, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.references :parent, foreign_key: { to_table: :posts, on_delete: :cascade }
      t.text :body, null: false
      t.integer :likes_count, null: false, default: 0
      t.timestamps
    end

    create_table :post_likes do |t|
      t.references :post, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end
    add_index :post_likes, %i[post_id user_id], unique: true
  end
end

class CreateWikiPages < ActiveRecord::Migration[8.0]
  def change
    create_table :pages do |t|
      t.string :title, null: false
      t.string :slug, null: false, collation: "utf8mb4_bin" # case-sensitive: wiki titles differ by case
      t.integer :pageid
      t.integer :revid
      t.string :category, null: false, default: "Uncategorized"
      t.json :categories
      t.text :summary
      t.string :source_url, limit: 500
      t.text :body, size: :medium
      t.integer :word_count, null: false, default: 0
      t.integer :links_out_count, null: false, default: 0
      t.integer :links_in_count, null: false, default: 0
      t.datetime :fetched_at
      t.timestamps
    end
    add_index :pages, :slug, unique: true
    add_index :pages, :category
    add_index :pages, :title
    add_index :pages, %i[title body], type: :fulltext

    create_table :page_links do |t|
      t.references :from_page, null: false, foreign_key: { to_table: :pages, on_delete: :cascade }
      t.references :to_page, null: false, foreign_key: { to_table: :pages, on_delete: :cascade }
    end
    add_index :page_links, %i[from_page_id to_page_id], unique: true
  end
end

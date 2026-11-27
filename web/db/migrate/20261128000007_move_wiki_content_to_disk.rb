# Wiki content stays in the dist/ folder as Markdown files. The database only keeps panel data
# (discussions, analytics, accounts), which refers to a wiki page by its slug.
class MoveWikiContentToDisk < ActiveRecord::Migration[8.0]
  def up
    remove_reference :topics, :page, foreign_key: true, index: true
    add_column :topics, :page_slug, :string, null: false, default: "", collation: "utf8mb4_bin"
    add_index :topics, :page_slug

    remove_reference :page_views, :page, foreign_key: true, index: true
    add_column :page_views, :page_slug, :string, collation: "utf8mb4_bin"
    add_index :page_views, %i[page_slug created_at]

    drop_table :page_links
    drop_table :pages
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "page content now lives in dist/"
  end
end

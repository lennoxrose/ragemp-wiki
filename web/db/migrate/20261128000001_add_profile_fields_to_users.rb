class AddProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :role, :string, null: false, default: "member"
    add_column :users, :username, :string
    add_column :users, :display_name, :string
    add_column :users, :bio, :string, limit: 160
    add_column :users, :disabled_at, :datetime
    add_column :users, :last_seen_at, :datetime
    add_column :users, :preferences, :json
    execute "UPDATE users SET username = LOWER(REGEXP_REPLACE(SUBSTRING_INDEX(email, '@', 1), '[^a-z0-9_]', '_')) WHERE username IS NULL"
    add_index :users, :username, unique: true
    add_index :users, :role
  end

  def down
    remove_index :users, :role
    remove_index :users, :username
    %i[preferences last_seen_at disabled_at bio display_name username role].each { |c| remove_column :users, c }
  end
end

class CreateAccessAndAdminTables < ActiveRecord::Migration[8.0]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :last4, null: false
      t.string :scope, null: false, default: "read"
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true

    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :token_digest, null: false
      t.string :user_agent
      t.string :ip
      t.datetime :last_active_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :user_sessions, :token_digest, unique: true

    create_table :admin_events do |t|
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :action, null: false
      t.string :subject
      t.datetime :created_at, null: false
    end
    add_index :admin_events, :created_at

    create_table :sync_runs do |t|
      t.string :trigger, null: false, default: "manual"
      t.references :triggered_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :mode, null: false, default: "vault"
      t.boolean :full, null: false, default: false
      t.string :status, null: false, default: "running"
      t.string :phase
      t.integer :listed, null: false, default: 0
      t.integer :total, null: false, default: 0
      t.integer :changed, null: false, default: 0
      t.integer :removed, null: false, default: 0
      t.integer :done, null: false, default: 0
      t.integer :written, null: false, default: 0
      t.integer :failed, null: false, default: 0
      t.integer :batches, null: false, default: 0
      t.text :error
      t.text :log, size: :medium
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end
    add_index :sync_runs, :started_at

    create_table :sync_settings do |t|
      t.boolean :enabled, null: false, default: false
      t.string :frequency, null: false, default: "daily"
      t.string :run_at, null: false, default: "03:00"
      t.string :time_zone, null: false, default: "Europe/Berlin"
      t.string :cron
      t.string :mode, null: false, default: "vault"
      t.integer :batch, null: false, default: 50
      t.integer :namespace, null: false, default: 0
      t.boolean :weekly_full, null: false, default: false
      t.datetime :next_run_at
      t.timestamps
    end
  end
end

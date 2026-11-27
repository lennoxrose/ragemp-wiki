class AddLoginAttemptsAndSyncPid < ActiveRecord::Migration[8.0]
  def change
    create_table :login_attempts do |t|
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :outcome, null: false # success, wrong_password or disabled
      t.datetime :created_at, null: false
    end
    add_index :login_attempts, :created_at

    add_column :sync_runs, :pid, :integer
  end
end

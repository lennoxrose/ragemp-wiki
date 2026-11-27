class CreateInviteCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :invite_codes do |t|
      t.string :code, null: false, index: { unique: true }
      t.references :created_by, foreign_key: { to_table: :users }, null: true # null = created from the command line
      t.references :used_by, foreign_key: { to_table: :users }, null: true, index: { unique: true }
      t.datetime :used_at
      t.timestamps
    end
  end
end

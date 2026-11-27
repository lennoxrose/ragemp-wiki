class AddRevokedAtToInviteCodes < ActiveRecord::Migration[8.0]
  def change
    add_column :invite_codes, :revoked_at, :datetime
  end
end

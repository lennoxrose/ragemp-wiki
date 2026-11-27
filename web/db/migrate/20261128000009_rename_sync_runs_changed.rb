# "changed" clashes with ActiveRecord's own dirty-tracking method of that name.
class RenameSyncRunsChanged < ActiveRecord::Migration[8.0]
  def change
    rename_column :sync_runs, :changed, :changed_count
  end
end

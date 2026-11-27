# Starts scheduled sync runs. Checked every 30 seconds by a thread in the web process (see the initializer).
class SyncScheduler
  def self.tick(now = Time.current)
    settings = SyncSetting.instance
    return unless settings.enabled && settings.next_run_at && settings.next_run_at <= now
    unless SyncRun.active.exists?
      full = settings.frequency == "weekly" || (settings.weekly_full && now.in_time_zone(settings.zone).sunday?)
      run = SyncRun.queue!(trigger: "scheduled", full: full, settings: settings)
      SyncRunner.dispatch(run)
    end
    settings.update!(next_run_at: settings.compute_next(now))
  end
end

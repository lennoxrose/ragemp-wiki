module Admin
  class SyncController < BaseController
    def show
      @settings = SyncSetting.instance
      @active = SyncRun.active.recent.first
      @run = @active || SyncRun.recent.first
      @history = SyncRun.recent.limit(6)
      @pages = Wiki.library.count
      @failed_batches = SyncRun.where("started_at >= ?", 30.days.ago).sum(:failed)
      @last_failure = SyncRun.where(status: %w[failed warnings]).recent.first
      @local_runner = SyncRunner.available?
      @lines = @run ? @run.log_lines.last(300) : []
    end

    def run
      return redirect_to(admin_sync_path, alert: "A sync is already running.") if SyncRun.active.exists?
      run = SyncRun.queue!(trigger: "manual", user: current_user, full: params[:full] == "1")
      log_event("started a #{run.full ? "full resync" : "sync"}")
      if SyncRunner.dispatch(run)
        redirect_to admin_sync_path, notice: "Sync started."
      else
        redirect_to admin_sync_path, notice: "Sync queued. It starts when the wikisync application picks it up through the v2 API."
      end
    end

    def stop
      run = SyncRun.active.recent.first
      return redirect_to(admin_sync_path, alert: "Nothing is running.") unless run
      Process.kill("TERM", run.pid) if run.pid && run.status == "running" rescue nil
      run.update!(status: "cancelled", finished_at: Time.current)
      log_event("stopped the running sync")
      redirect_to admin_sync_path, notice: "Sync stopped."
    end

    def settings
      s = SyncSetting.instance
      s.assign_attributes(params.permit(:frequency, :run_at, :time_zone, :cron, :mode, :batch, :namespace).to_h)
      s.enabled = params[:enabled] == "1"
      s.weekly_full = params[:weekly_full] == "1"
      if s.save
        s.schedule!
        log_event("changed the sync schedule")
        redirect_to admin_sync_path, notice: s.enabled ? "Schedule saved. Next run #{s.next_run_at.in_time_zone(s.zone).strftime("%b %-d, %H:%M")}." : "Schedule saved. Automatic syncs are off."
      else
        redirect_to admin_sync_path, alert: s.errors.full_messages.to_sentence
      end
    end

    def log
      run = params[:run_id] ? SyncRun.find(params[:run_id]) : SyncRun.recent.first
      return redirect_to(admin_sync_path, alert: "There is no log yet.") unless run
      text = run.log_lines.map { |l| "#{l[:time]}  #{l[:level].to_s.ljust(5)} #{l[:message]}" }.join("\n")
      send_data text + "\n", type: "text/plain; charset=utf-8", disposition: "attachment", filename: "sync-#{run.id}.log"
    end
  end
end

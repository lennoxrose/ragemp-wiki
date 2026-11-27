module Api
  module V1
    # Live status for the admin Sync page. Does not exist for anyone but signed-in administrators.
    class SyncController < BaseController
      skip_before_action :require_internal_session
      prepend_before_action :hide_from_non_admins

      def status
        run = SyncRun.active.recent.first || SyncRun.recent.first
        render json: { run: run && serialize(run), settings: { enabled: SyncSetting.instance.enabled, next_run_at: SyncSetting.instance.next_run_at } }
      end

      private

      def serialize(run)
        { id: run.id, status: run.status, phase: run.phase, trigger: run.trigger, listed: run.listed, total: run.total, changed: run.changed_count,
          removed: run.removed, done: run.done, written: run.written, failed: run.failed, percent: run.percent, batches: run.batches,
          started_at: run.started_at, finished_at: run.finished_at, error: run.error, active: run.active?, lines: run.log_lines.last(300) }
      end
    end
  end
end

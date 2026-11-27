module Api
  module V2
    # How the wikisync application talks to the panel: ask what to do, claim a run, stream its events, finish it.
    class SyncController < BaseController
      before_action :find_run, only: %i[claim events finish]

      # GET /api/v2/sync/config: options for the next run, and the queued run to start if there is one.
      # (The action is called `options` because `config` is a method every Rails controller already has.)
      def options
        s = SyncSetting.instance
        pending = SyncRun.where(status: "queued").order(:started_at).first
        render json: {
          options: { mode: s.mode, batch: s.batch, namespace: s.namespace, out: Wiki.root.to_s },
          schedule: { enabled: s.enabled, frequency: s.frequency, next_run_at: s.next_run_at },
          pending: pending && { id: pending.id, full: pending.full, mode: pending.mode, trigger: pending.trigger }
        }
      end

      # POST /api/v2/sync/runs: the tool started on its own (for example from the command line) and reports it.
      def create
        run = SyncRun.create!(trigger: "agent", mode: params[:mode].presence_in(SyncSetting::MODES) || SyncSetting.instance.mode,
                              full: params[:full] == true, status: "running", started_at: Time.current)
        render json: { id: run.id }, status: :created
      end

      def claim
        return render(json: { error: { code: "not_queued", message: "This run is already #{@run.status}." } }, status: :conflict) unless @run.status == "queued"
        @run.update!(status: "running")
        render json: { id: @run.id, full: @run.full, mode: @run.mode }
      end

      # POST /api/v2/sync/runs/:id/events with {"events": [...]} or a body of NDJSON lines, the same lines `wikisync -json` prints.
      def events
        list = params[:events].is_a?(Array) ? params[:events].map { |e| e.respond_to?(:to_unsafe_h) ? e.to_unsafe_h : e } : request.raw_post.to_s.lines.filter_map { |l| JSON.parse(l) rescue nil }
        @run.apply_events(list.first(2000))
        render json: { run: { status: @run.status, done: @run.done, written: @run.written } }
      end

      def finish
        failed = params[:failed].to_i
        if params[:error].present?
          @run.update!(status: "failed", error: params[:error].to_s.first(1000), finished_at: Time.current)
        elsif @run.active?
          @run.update!(status: failed.positive? ? "warnings" : "success", failed: failed, finished_at: Time.current)
        end
        Wiki.reload! if @run.status.in?(%w[success warnings])
        render json: { status: @run.status, pages: Wiki.library.count }
      end

      # POST /api/v2/sync/refresh: the tool rewrote dist/ and wants the panel to reread it.
      def refresh
        Wiki.reload!
        render json: { pages: Wiki.library.count, categories: Wiki.library.categories.size }
      end

      private

      def find_run = (@run = SyncRun.find(params[:id]))
    end
  end
end

require "rubygems/package"
require "zlib"

module Api
  module V2
    # How the wikisync application talks to the panel: ask what to do, claim a run, stream its events, finish it.
    class SyncController < BaseController
      MAX_FILE = 32.megabytes
      DELETED_LIST = ".wikisync-deleted".freeze

      before_action :find_run, only: %i[claim events files finish]

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

      # POST /api/v2/sync/runs/:id/files: a remote agent (wikisync-remote) sends the pages it wrote as a gzip tarball.
      # Entries are written under the wiki root; the entry `.wikisync-deleted` lists paths to remove, one per line.
      def files
        root = Wiki.root.expand_path
        written = removed = 0
        Zlib::GzipReader.wrap(request.body) do |gz|
          Gem::Package::TarReader.new(gz) do |tar|
            tar.each do |entry|
              next unless entry.file?
              return deny(:unprocessable_content, "too_large", "#{entry.full_name} is over #{MAX_FILE / 1.megabyte} MB.") if entry.header.size > MAX_FILE
              if entry.full_name == DELETED_LIST
                entry.read.to_s.each_line do |line|
                  path = safe_path(root, line.chomp)
                  (File.delete(path); removed += 1) if path && File.file?(path)
                end
              elsif (path = safe_path(root, entry.full_name))
                FileUtils.mkdir_p(path.dirname)
                File.binwrite("#{path}.part", entry.read)
                File.rename("#{path}.part", path) # readers never see a half-written page
                written += 1
              else
                return deny(:unprocessable_content, "bad_path", "Refusing path #{entry.full_name.inspect}.")
              end
            end
          end
        end
        render json: { written: written, removed: removed }
      rescue Zlib::Error, Gem::Package::Error => e
        deny(:bad_request, "bad_archive", e.message)
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

      # A path inside the wiki root, or nil when +name+ would escape it.
      def safe_path(root, name)
        return if name.empty? || name.include?("\0")
        path = root.join(name).expand_path
        path if path.to_s.start_with?("#{root}#{File::SEPARATOR}")
      end

      def find_run = (@run = SyncRun.find(params[:id]))
    end
  end
end

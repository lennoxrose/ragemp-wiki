require "json"
require "singleton"

module Wiki
  # In-memory index over dist/.manifest.json (titles, categories, summaries) plus the link graph between pages.
  # It reloads itself when wikisync rewrites the manifest. Page bodies are read from the files on demand.
  class Library
    include Singleton

    Entry = Struct.new(:title, :slug, :path, :category, :categories, :summary, :pageid, :revid, keyword_init: true)
    LINK_RE = %r{\]\(https?://wiki\.rage\.mp/wiki/([^)\s"]+)}i
    CHECK_EVERY = 5 # seconds between looking at the manifest's modification time

    def initialize
      @mutex = Mutex.new
      @checked_at = -CHECK_EVERY
      @mtime = nil
      @by_slug = {}
      @entries = []
      @categories = {}
      @graph = nil
    end

    # ---- lookups -----------------------------------------------------------------------------------------------
    def entries = (refresh!; @entries)
    def count = entries.size
    def slug?(slug) = (refresh!; @by_slug.key?(slug))
    def page(slug) = (refresh!; (e = @by_slug[slug]) && Page.new(e))
    def category_of(slug) = (refresh!; @by_slug[slug]&.category)
    def pages(slugs) = slugs.filter_map { |s| page(s) }
    def category_names = (refresh!; @categories.keys)

    # [[name, count], ...] biggest first
    def categories
      refresh!
      @categories.map { |name, list| [name, list.size] }.sort_by { |name, n| [-n, name] }
    end

    def in_category(name)
      refresh!
      (@categories[name] || []).sort_by { |e| e.title.downcase }.map { |e| Page.new(e) }
    end

    def manifest_updated_at = (refresh!; @mtime)

    # ---- search ------------------------------------------------------------------------------------------------
    # Title and summary matches come from memory. If there is still room, page bodies are scanned for the
    # words, within a small time budget, so one broad query cannot tie up the server.
    def search(query, limit: 25, body_budget: 1.2)
      q = query.to_s.strip.downcase
      return [] if q.empty?
      words = q.split
      graph = self.graph
      scored = entries.filter_map do |e|
        t = e.title.downcase
        score = if t == q then 100 elsif t.start_with?(q) then 80 elsif t.include?(q) then 60
                elsif words.all? { |w| t.include?(w) } then 50 elsif e.summary.to_s.downcase.include?(q) then 20 end
        score && [score + Math.log(graph["in"].fetch(e.slug, []).size + 1), e]
      end
      hits = scored.sort_by { |s, e| [-s, e.title.length] }.first(limit).map(&:last)
      if hits.size < limit && q.length >= 3
        seen = hits.map(&:slug).to_set
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + body_budget
        entries.each do |e|
          break if hits.size >= limit || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          next if seen.include?(e.slug)
          text = read_file(e)&.downcase or next
          hits << e if words.all? { |w| text.include?(w) }
        end
      end
      hits.map { |e| Page.new(e) }
    end

    # ---- link graph --------------------------------------------------------------------------------------------
    # { "out" => { slug => [slug] }, "in" => { slug => [slug] } }, cached in tmp/ until the manifest changes.
    def graph
      refresh!
      @mutex.synchronize { @graph ||= load_or_build_graph }
    end

    # Compact data for the map: categories, one [title, category index, connections] per page, and flat link pairs.
    def graph_payload
      g = graph
      @mutex.synchronize { @payload ||= build_payload(g) }
    end

    # ---- files -------------------------------------------------------------------------------------------------
    def read_file(entry)
      path = file_path(entry)
      path&.read(encoding: "UTF-8")
    rescue SystemCallError
      nil
    end

    def reload!
      @mutex.synchronize { load_manifest }
    end

    private

    def manifest_path = Wiki.root.join(".manifest.json")

    def refresh!
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return if now - @checked_at < CHECK_EVERY
      @mutex.synchronize do
        @checked_at = now
        load_manifest if manifest_path.file? && manifest_path.mtime != @mtime
      end
    end

    def load_manifest
      path = manifest_path
      raise "No .manifest.json in #{Wiki.root}. Run wikisync first." unless path.file?
      raw = JSON.parse(path.read(encoding: "UTF-8")).fetch("entries")
      by_slug = {}
      raw.each do |title, e|
        slug = Wiki.slugify(title)
        by_slug[slug] = Entry.new(title: title, slug: slug, path: e["path"].to_s, category: e["path"].to_s.split("/").first || "Uncategorized",
                                  categories: Array(e["categories"]), summary: e["summary"].to_s, pageid: e["pageid"], revid: e["revid"])
      end
      @by_slug = by_slug
      @entries = by_slug.values.sort_by { |e| e.title.downcase }
      @categories = @entries.group_by(&:category)
      @mtime = path.mtime
      @graph = nil
      @payload = nil
    end

    def build_payload(g)
      names = @categories.keys.sort_by { |n| [-@categories[n].size, n] }
      index = names.each_with_index.to_h
      position = {}
      @entries.each_with_index { |e, i| position[e.slug] = i }
      nodes = @entries.map { |e| [e.title, index[e.category], g["out"].fetch(e.slug, []).size + g["in"].fetch(e.slug, []).size] }
      links = []
      g["out"].each { |from, targets| targets.each { |to| links << position[from] << position[to] if position[from] && position[to] } }
      helpers = ApplicationController.helpers
      { version: @mtime.to_i, categories: names.map { |n| { name: n, count: @categories[n].size, color: helpers.category_color(n) } }, nodes: nodes, links: links }
    end

    # Only paths below the wiki root are ever read, whatever the manifest says.
    def file_path(entry)
      root = Wiki.root.expand_path
      full = root.join(entry.path).expand_path
      full.to_s.start_with?("#{root}#{File::SEPARATOR}") && full.file? ? full : nil
    end

    def load_or_build_graph
      cache = Rails.root.join("tmp", "wiki-graph.json")
      key = [@mtime.to_f, @by_slug.size]
      if cache.file?
        data = JSON.parse(cache.read) rescue nil
        return { "out" => data["out"], "in" => data["in"] } if data && data["key"] == key
      end
      out = {}
      inn = Hash.new { |h, k| h[k] = [] }
      @entries.each do |e|
        text = read_file(e).to_s
        targets = text.scan(LINK_RE).flatten.map { |t| CGI.unescape(t.sub(/#.*\z/, "")).tr(" ", "_") }.select { |s| @by_slug.key?(s) }.uniq - [e.slug]
        out[e.slug] = targets
        targets.each { |t| inn[t] << e.slug }
      end
      graph = { "out" => out, "in" => inn.to_h }
      FileUtils.mkdir_p(cache.dirname)
      cache.write(JSON.generate(graph.merge("key" => key)))
      graph
    end
  end
end

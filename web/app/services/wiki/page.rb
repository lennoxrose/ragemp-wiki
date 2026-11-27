require "yaml"

module Wiki
  # One page of the mirror: metadata from the manifest, content read from its Markdown file.
  class Page
    attr_reader :entry

    delegate :title, :slug, :category, :categories, :summary, :pageid, :revid, :path, to: :entry

    def initialize(entry) = @entry = entry

    def to_param = slug
    def ==(other) = other.is_a?(Page) && other.slug == slug
    alias eql? ==
    def hash = slug.hash

    def raw = (@raw ||= Wiki.library.read_file(entry).to_s)

    def front_matter
      @front_matter ||= split[0]
    end

    def body = (@body ||= split[1])
    def source_url = front_matter["url"].presence
    def fetched_at = (v = front_matter["fetched"]) && (v.respond_to?(:to_time) ? v.to_time : (Time.zone.parse(v.to_s) rescue nil))
    def word_count = body.scan(/\S+/).size
    def file_missing? = raw.empty?

    def out_slugs = Wiki.library.graph["out"].fetch(slug, [])
    def in_slugs = Wiki.library.graph["in"].fetch(slug, [])
    def links_out = Wiki.library.pages(out_slugs)
    def links_in = Wiki.library.pages(in_slugs)

    private

    def split
      @split ||= begin
        if raw.start_with?("---")
          _, front, body = raw.split(/^---\s*$/, 3)
          meta = YAML.safe_load(front.to_s, permitted_classes: [Time, Date]) rescue {}
          [meta.is_a?(Hash) ? meta : {}, body.to_s.lstrip]
        else
          [{}, raw]
        end
      end
    end
  end
end

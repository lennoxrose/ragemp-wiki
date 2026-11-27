require "kramdown"
require "kramdown/parser/gfm"

# Turns a wiki page's Markdown file into sanitized HTML. Links that point at other wiki pages become local
# links, and headings get ids so the article can show a table of contents.
class MarkdownRenderer
  Result = Struct.new(:html, :toc, keyword_init: true)
  WIKI_URL = %r{\Ahttps?://wiki\.rage\.mp/wiki/(?<target>[^?#]+)}i
  ALLOWED_ATTRIBUTES = (ActionView::Base.sanitized_allowed_attributes + %w[id class target rel loading]).freeze

  def self.call(page) = new(page).call

  def initialize(page) = @page = page

  def call
    markdown = @page.body.to_s.sub(/\A#\s+[^\n]*\n+/, "") # the page title is already the article heading
    html = Kramdown::Document.new(markdown, input: "GFM", hard_wrap: false, syntax_highlighter: nil).to_html
    doc = Nokogiri::HTML5.fragment(html)
    toc = number_headings(doc)
    rewrite_links(doc)
    doc.css("img").each { |img| img["loading"] = "lazy" }
    safe = ActionController::Base.helpers.sanitize(doc.to_html, attributes: ALLOWED_ATTRIBUTES)
    Result.new(html: safe.html_safe, toc: toc)
  end

  private

  def number_headings(doc)
    used = Hash.new(0)
    doc.css("h2, h3").map do |h|
      base = h.text.parameterize.presence || "section"
      used[base] += 1
      id = used[base] > 1 ? "#{base}-#{used[base]}" : base
      h["id"] = id
      { level: h.name[1].to_i, id: id, text: h.text.strip }
    end
  end

  def rewrite_links(doc)
    doc.css("a[href]").each do |a|
      slug = wiki_slug(a["href"])
      if slug && Wiki.library.slug?(slug)
        a["href"] = "/wiki/#{ERB::Util.url_encode(slug)}"
        a.remove_attribute("title")
      elsif a["href"].to_s.match?(%r{\Ahttps?://}i)
        a["target"] = "_blank"
        a["rel"] = "noopener noreferrer"
      end
    end
  end

  def wiki_slug(href)
    m = WIKI_URL.match(href.to_s) or return nil
    CGI.unescape(m[:target]).tr(" ", "_")
  end
end

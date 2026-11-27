class PagesController < ApplicationController
  before_action :find_page!

  def show
    @render = MarkdownRenderer.call(@page)
    @links_out = @page.links_out.first(14)
    @links_in = @page.links_in.first(14)
    PageView.record(@page.slug, current_user)
  end

  def source; end

  def raw
    send_data @page.raw, type: "text/markdown; charset=utf-8", disposition: "attachment", filename: "#{@page.slug.gsub(/[^\w.-]/, "_")}.md"
  end
end

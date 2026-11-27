module Api
  module V3
    class PagesController < BaseController
      # GET /api/v3/pages?q=&category=&page=&per_page=
      def index
        list = if params[:q].present?
                 Wiki.library.search(params[:q].to_s.first(120), limit: 100)
               elsif params[:category].present?
                 Wiki.library.in_category(params[:category].to_s)
               else
                 Wiki.library.entries.map { |e| Wiki::Page.new(e) }
               end
        total = list.size
        slice = list.slice((page_number - 1) * per_page, per_page) || []
        render json: { data: slice.map { |p| page_summary(p) }, meta: { total: total, page: page_number, per_page: per_page } }
      end

      # GET /api/v3/pages/:slug (add ?as=markdown, or send Accept: text/markdown, for the raw Markdown)
      def show
        page = Wiki.find(params[:slug])
        return deny(:not_found, "not_found", "No page called #{params[:slug]}.") unless page
        return unless stale?(etag: [page.revid, page.slug], public: false)
        if params[:as] == "markdown" || request.headers["Accept"].to_s.include?("text/markdown")
          render plain: page.body, content_type: "text/markdown; charset=utf-8"
        else
          render json: { data: page_summary(page).merge(
            categories: page.categories, revision: page.revid, page_id: page.pageid, source_url: page.source_url, fetched_at: page.fetched_at,
            word_count: page.word_count, markdown: page.body,
            links_out: page.links_out.map { |p| { title: p.title, slug: p.slug } }, links_in: page.links_in.map { |p| { title: p.title, slug: p.slug } }
          ) }
        end
      end
    end
  end
end

module Api
  module V3
    class SearchController < BaseController
      def index
        q = params[:q].to_s.strip.first(120)
        return deny(:bad_request, "missing_query", "Pass the search words as ?q=.") if q.empty?
        results = Wiki.library.search(q, limit: per_page)
        render json: { data: results.map { |p| page_summary(p) }, meta: { query: q, count: results.size } }
      end
    end
  end
end

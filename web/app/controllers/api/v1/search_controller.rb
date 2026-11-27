module Api
  module V1
    class SearchController < BaseController
      # Title suggestions for the site's search boxes.
      def index
        pages = Wiki.library.search(params[:q].to_s.first(80), limit: 8, body_budget: 0)
        render json: { results: pages.map { |p| { title: p.title, slug: p.slug, category: p.category } } }
      end
    end
  end
end

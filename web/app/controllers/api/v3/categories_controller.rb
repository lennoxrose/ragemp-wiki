module Api
  module V3
    class CategoriesController < BaseController
      def index
        render json: { data: Wiki.library.categories.map { |name, count| { name: name, count: count, url: api_v3_category_url(name: name) } } }
      end

      def show
        pages = Wiki.library.in_category(params[:name].to_s)
        return deny(:not_found, "not_found", "No category called #{params[:name]}.") if pages.empty?
        slice = pages.slice((page_number - 1) * per_page, per_page) || []
        render json: { data: { name: params[:name], count: pages.size, pages: slice.map { |p| page_summary(p) } }, meta: { total: pages.size, page: page_number, per_page: per_page } }
      end
    end
  end
end

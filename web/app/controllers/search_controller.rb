class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip.first(120)
    @results = @query.present? ? Wiki.library.search(@query, limit: 40) : []
    SearchLog.create!(user: current_user, query: @query, results_count: @results.size, created_at: Time.current) if @query.present?
    redirect_to wiki_page_path(@results.first.slug) if @results.size == 1 && @results.first.title.casecmp?(@query)
  end
end

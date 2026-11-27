module Admin
  class AnalyticsController < BaseController
    def show
      @analytics = Analytics.new(params[:range])
    end

    def export
      analytics = Analytics.new(params[:range])
      send_data analytics.to_csv, type: "text/csv; charset=utf-8", disposition: "attachment", filename: "wiki-analytics-#{analytics.range}.csv"
    end
  end
end

module Api
  module V1
    class GraphController < BaseController
      def show
        payload = Wiki.library.graph_payload
        return unless stale?(etag: [payload[:version], payload[:nodes].size], public: false)
        render json: payload
      end
    end
  end
end

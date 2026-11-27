module Api
  module V3
    # The link graph between pages, in a readable shape: nodes with title, slug and category; edges as index pairs.
    class GraphController < BaseController
      def show
        payload = Wiki.library.graph_payload
        return unless stale?(etag: [payload[:version], payload[:nodes].size], public: false)
        names = payload[:categories].map { |c| c[:name] }
        nodes = payload[:nodes].map { |title, cat, degree| { title: title, slug: Wiki.slugify(title), category: names[cat], connections: degree } }
        render json: { data: { nodes: nodes, edges: payload[:links].each_slice(2).to_a } }
      end
    end
  end
end

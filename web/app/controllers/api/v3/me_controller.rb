module Api
  module V3
    class MeController < BaseController
      def show
        render json: { data: { user: { username: token.user.username, name: token.user.name },
                               token: { name: token.name, scope: token.scope, expires_at: token.expires_at, last4: token.last4 },
                               wiki: { pages: Wiki.library.count, categories: Wiki.library.categories.size, updated_at: Wiki.library.manifest_updated_at } } }
      end
    end
  end
end

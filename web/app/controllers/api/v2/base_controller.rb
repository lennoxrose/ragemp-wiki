require "digest"

module Api
  module V2
    # API for the wikisync application. It authenticates with one service key (WIKISYNC_API_KEY), not with a user.
    class BaseController < ActionController::API
      before_action :require_service_key

      private

      def require_service_key
        key = ENV["WIKISYNC_API_KEY"].to_s
        return deny(:service_unavailable, "not_configured", "WIKISYNC_API_KEY is not set on the server.") if key.empty?
        given = request.authorization.to_s.delete_prefix("Bearer ").strip
        ok = ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(given), Digest::SHA256.hexdigest(key))
        deny(:unauthorized, "bad_key", "Missing or wrong service key.") unless ok
      end

      def deny(status, code, message)
        render json: { error: { code: code, message: message } }, status: status
      end
    end
  end
end

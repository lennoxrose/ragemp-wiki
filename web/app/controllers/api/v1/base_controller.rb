module Api
  module V1
    # Internal API: only the site's own pages call it, from a signed-in browser on the same origin.
    # Bearer tokens and requests from other sites are refused.
    class BaseController < ActionController::API
      before_action :require_internal_session

      attr_reader :current_user

      private

      def require_internal_session
        return deny(:forbidden, "internal_only", "The internal API does not accept API tokens.") if request.authorization.present?
        return deny(:forbidden, "internal_only", "The internal API is only available to the site itself.") unless same_origin?
        @current_user = internal_user
        deny(:unauthorized, "not_signed_in", "Sign in first.") unless @current_user
      end

      # The signed-in member behind a same-origin browser request, or nil.
      def internal_user
        return nil if request.authorization.present? || !same_origin?
        user = UserSession.for(request.session[:sid])&.user
        user if user && !user.disabled?
      end

      def same_origin?
        site = request.headers["Sec-Fetch-Site"]
        return site == "same-origin" if site.present?
        from = request.headers["Origin"].presence || request.headers["Referer"].presence
        from.present? && URI.parse(from).host == request.host
      rescue URI::InvalidURIError
        false
      end

      # For admin-only endpoints: anyone else gets the same "not found" as an undefined address.
      def hide_from_non_admins
        @current_user = internal_user
        return if @current_user&.admin?
        raise ActionController::RoutingError, "No route matches [#{request.request_method}] #{request.path.inspect}"
      end

      def deny(status, code, message)
        render json: { error: { code: code, message: message } }, status: status
      end
    end
  end
end

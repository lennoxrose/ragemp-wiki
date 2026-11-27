module Api
  module V3
    # Public read API. Every request needs an API token: Authorization: Bearer wiki_...
    class BaseController < ActionController::API
      LIMIT = 120 # requests per token per minute
      HITS = {}
      LOCK = Mutex.new

      before_action :require_token
      before_action :rate_limit

      # Fixed one minute window per token. Returns [allowed, remaining].
      def self.hit(token_id)
        window = Time.now.to_i / 60
        LOCK.synchronize do
          w, n = HITS[token_id]
          n = w == window ? n + 1 : 1
          HITS[token_id] = [window, n]
          HITS.delete_if { |_, (win, _)| win < window - 1 } if HITS.size > 5000
          [n <= LIMIT, [LIMIT - n, 0].max]
        end
      end

      attr_reader :token

      private

      def require_token
        raw = request.authorization.to_s.delete_prefix("Bearer ").strip
        return deny(:unauthorized, "token_required", "Send an API token as 'Authorization: Bearer wiki_...'. Create one on your Account page.") if raw.empty?
        @token = ApiToken.authenticate(raw)
        deny(:unauthorized, "invalid_token", "This token is unknown, revoked or expired.") unless @token
      end

      def rate_limit
        ok, remaining = BaseController.hit(@token.id)
        response.set_header("X-RateLimit-Limit", LIMIT.to_s)
        response.set_header("X-RateLimit-Remaining", remaining.to_s)
        deny(:too_many_requests, "rate_limited", "Limit of #{LIMIT} requests per minute reached.") unless ok
      end

      def deny(status, code, message)
        render json: { error: { code: code, message: message } }, status: status
      end

      def page_summary(page)
        { title: page.title, slug: page.slug, category: page.category, summary: page.summary, url: api_v3_page_url(slug: page.slug) }
      end

      def per_page = [[params.fetch(:per_page, 50).to_i, 1].max, 100].min
      def page_number = [params.fetch(:page, 1).to_i, 1].max
    end
  end
end

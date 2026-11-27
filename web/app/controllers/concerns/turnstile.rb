require "net/http"

# Cloudflare Turnstile gate for the login/register forms.
# Outside production the keys fall back to Cloudflare's always-pass test keys.
module Turnstile
  extend ActiveSupport::Concern

  VERIFY_URL = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")
  TEST_SITE_KEY = "1x00000000000000000000AA"
  TEST_SECRET_KEY = "1x0000000000000000000000000000000AA"

  included do
    before_action :verify_turnstile, only: :create
    helper_method :turnstile_site_key
  end

  private

  def turnstile_site_key = ENV["TURNSTILE_SITE_KEY"].presence || (TEST_SITE_KEY unless Rails.env.production?)

  def verify_turnstile
    secret = ENV["TURNSTILE_SECRET_KEY"].presence || (TEST_SECRET_KEY unless Rails.env.production?)
    token = params["cf-turnstile-response"].to_s
    ok = secret && token.present? && begin
      res = Net::HTTP.post_form(VERIFY_URL, secret: secret, response: token, remoteip: request.remote_ip)
      JSON.parse(res.body)["success"] == true
    rescue StandardError => e
      Rails.logger.warn("Turnstile verify failed: #{e.class}")
      false
    end
    return if ok
    flash.now[:error] = "Please complete the human verification and try again"
    render :new, status: :unprocessable_content
  end
end

require "digest"

# One row per signed-in browser, so members can see their devices and sign others out.
class UserSession < ApplicationRecord
  belongs_to :user

  def self.start(user, request)
    raw = SecureRandom.urlsafe_base64(32)
    create!(user: user, token_digest: Digest::SHA256.hexdigest(raw), user_agent: request.user_agent.to_s.first(255),
            ip: request.remote_ip, last_active_at: Time.current, created_at: Time.current)
    raw
  end

  def self.for(raw)
    return nil if raw.blank?
    find_by(token_digest: Digest::SHA256.hexdigest(raw))
  end

  def device
    ua = user_agent.to_s
    browser = case ua
              when /Edg\//i then "Edge" when /OPR\//i then "Opera" when /Firefox/i then "Firefox"
              when /Chrome/i then "Chrome" when /Safari/i then "Safari" else "Browser" end
    os = case ua
         when /Windows/i then "Windows" when /iPhone|iPad/i then "iOS" when /Android/i then "Android"
         when /Mac OS/i then "macOS" when /Linux/i then "Linux" else "unknown system" end
    "#{browser} on #{os}"
  end

  def mobile? = user_agent.to_s.match?(/iPhone|Android|Mobile/i)
end

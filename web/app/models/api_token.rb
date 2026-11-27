require "digest"

# Tokens for /api/v3. The raw value is shown once at creation; only a SHA-256 digest and the last 4 characters are stored.
class ApiToken < ApplicationRecord
  PREFIX = "wiki_".freeze
  SCOPES = %w[read].freeze
  EXPIRY_CHOICES = { "30 days" => 30, "90 days" => 90, "1 year" => 365, "No expiry" => nil }.freeze

  belongs_to :user
  attr_reader :raw_token

  validates :name, presence: true, length: { maximum: 60 }
  validates :scope, inclusion: { in: SCOPES }

  scope :live, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.digest(raw) = Digest::SHA256.hexdigest(raw.to_s)

  def self.issue(user:, name:, expires_in_days: 90)
    raw = PREFIX + SecureRandom.alphanumeric(32)
    token = new(user: user, name: name, token_digest: digest(raw), last4: raw[-4, 4],
                expires_at: expires_in_days && expires_in_days.days.from_now)
    token.instance_variable_set(:@raw_token, raw)
    token.save
    token
  end

  # Returns the token for a raw bearer value, or nil if unknown, revoked, expired or the owner is disabled.
  def self.authenticate(raw)
    return nil unless raw.to_s.start_with?(PREFIX)
    token = live.includes(:user).find_by(token_digest: digest(raw))
    return nil unless token && !token.user.disabled?
    token.touch_last_used
    token
  end

  def masked = "#{PREFIX}••••••••#{last4}"
  def expired? = expires_at.present? && expires_at <= Time.current
  def revoked? = revoked_at.present?
  def revoke! = update!(revoked_at: Time.current)

  def touch_last_used
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end
end

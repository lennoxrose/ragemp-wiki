class User < ApplicationRecord
  ROLES = %w[member editor admin].freeze
  ROLE_LABELS = { "member" => "Member", "editor" => "Editor", "admin" => "Administrator" }.freeze
  DEFAULT_PREFERENCES = {
    "text_size" => "standard", "page_width" => "standard",
    "notify_replies" => true, "notify_mentions" => true, "notify_announcements" => true, "notify_digest" => false
  }.freeze

  has_secure_password
  attribute :preferences, :json # MariaDB reports JSON columns as plain text, so say so explicitly
  has_one_attached :avatar
  has_one_attached :banner
  has_many :api_tokens, dependent: :destroy
  has_many :user_sessions, dependent: :destroy
  has_many :topics, dependent: :nullify
  has_many :posts, dependent: :nullify
  has_many :created_invites, class_name: "InviteCode", foreign_key: :created_by_id, dependent: :nullify, inverse_of: :created_by
  has_many :used_invites, class_name: "InviteCode", foreign_key: :used_by_id, dependent: :nullify, inverse_of: :used_by

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.to_s.strip.downcase.delete_prefix("@") }
  before_validation :ensure_username, on: :create

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :username, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]{2,30}\z/, message: "can only use letters, numbers and underscores" }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :role, inclusion: { in: ROLES }
  validates :bio, length: { maximum: 160 }
  validates :display_name, length: { maximum: 60 }
  validate :avatar_and_banner_are_images

  scope :active, -> { where(disabled_at: nil) }
  scope :disabled, -> { where.not(disabled_at: nil) }
  scope :admins, -> { where(role: "admin") }

  def admin? = role == "admin"
  def editor? = role == "editor" || admin?
  def disabled? = disabled_at.present?
  def role_label = ROLE_LABELS.fetch(role, role.to_s.titleize)
  def name = display_name.presence || username
  def initial = name.to_s[0].to_s.upcase

  def pref(key)
    (preferences || {}).fetch(key.to_s) { DEFAULT_PREFERENCES.fetch(key.to_s) }
  end

  def update_preferences(attrs)
    merged = DEFAULT_PREFERENCES.merge(preferences || {})
    attrs.each { |k, v| merged[k.to_s] = v if DEFAULT_PREFERENCES.key?(k.to_s) }
    update(preferences: merged)
  end

  def disable! = update!(disabled_at: Time.current)
  def enable! = update!(disabled_at: nil)

  private

  def ensure_username
    return if username.present?
    base = email.to_s.split("@").first.to_s.downcase.gsub(/[^a-z0-9_]/, "_").presence || "member"
    candidate = base
    candidate = "#{base}#{rand(100..9999)}" while self.class.exists?(username: candidate)
    self.username = candidate
  end

  def avatar_and_banner_are_images
    { avatar: 5.megabytes, banner: 5.megabytes }.each do |name, max|
      att = public_send(name)
      next unless att.attached?
      errors.add(name, "must be a JPG, PNG or WebP image") unless att.blob.content_type.in?(%w[image/jpeg image/png image/webp])
      errors.add(name, "must be smaller than 5 MB") if att.blob.byte_size > max
    end
  end
end

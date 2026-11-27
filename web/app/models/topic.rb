class Topic < ApplicationRecord
  STATUSES = %w[open resolved].freeze

  belongs_to :user, optional: true
  has_many :posts, dependent: :destroy

  validates :page_slug, presence: true
  validates :title, presence: true, length: { maximum: 140 }
  validates :status, inclusion: { in: STATUSES }

  scope :for_page, ->(slug) { where(page_slug: slug) }
  scope :open_topics, -> { where(status: "open") }
  scope :resolved, -> { where(status: "resolved") }
  scope :recent, -> { order(pinned: :desc, last_activity_at: :desc) }

  def page = Wiki.find(page_slug)
  def resolved? = status == "resolved"
  def root_post = posts.where(parent_id: nil).order(:id).first

  def touch_activity! = update_columns(last_activity_at: Time.current, posts_count: posts.count)
end

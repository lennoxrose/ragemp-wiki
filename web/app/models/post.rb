class Post < ApplicationRecord
  belongs_to :topic
  belongs_to :user, optional: true
  belongs_to :parent, class_name: "Post", optional: true
  has_many :replies, class_name: "Post", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :post_likes, dependent: :delete_all

  validates :body, presence: true, length: { maximum: 5000 }
  validate :parent_belongs_to_topic
  after_create_commit { topic.touch_activity! }

  def liked_by?(user) = user && post_likes.exists?(user_id: user.id)

  def toggle_like(user)
    if (like = post_likes.find_by(user_id: user.id))
      like.destroy
    else
      post_likes.create!(user: user, created_at: Time.current)
    end
    update_columns(likes_count: post_likes.count)
  end

  private

  def parent_belongs_to_topic
    errors.add(:parent, "must be in the same topic") if parent && parent.topic_id != topic_id
  end
end

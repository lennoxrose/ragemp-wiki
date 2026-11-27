# Numbers and recent activity shown on a member's profile.
module ProfileData
  extend ActiveSupport::Concern

  private

  def load_profile(user)
    @profile = user
    @stats = {
      topics: Topic.where(user_id: user.id).count,
      replies: Post.where(user_id: user.id).where.not(parent_id: nil).count,
      likes: Post.where(user_id: user.id).sum(:likes_count)
    }
    @activity = recent_activity(user)
  end

  def recent_activity(user, limit: 6)
    topics = Topic.where(user_id: user.id).order(created_at: :desc).limit(limit).map { |t| { icon: "message-square", text: "Started the topic #{t.title}", page: t.page_slug, at: t.created_at } }
    replies = Post.where(user_id: user.id).where.not(parent_id: nil).includes(:topic).order(created_at: :desc).limit(limit).map do |p|
      { icon: "reply", text: "Replied in #{p.topic.title}", page: p.topic.page_slug, at: p.created_at }
    end
    (topics + replies).sort_by { |a| -a[:at].to_i }.first(limit)
  end
end

class TopicsController < ApplicationController
  MAIN_PAGE = "Main_Page".freeze
  before_action :set_context, only: %i[index create]

  def index
    @filter = params[:filter].presence_in(%w[open resolved]) || "all"
    all = Topic.for_page(@slug)
    @counts = { "all" => all.count, "open" => all.open_topics.count, "resolved" => all.resolved.count }
    scope = @filter == "all" ? all : all.where(status: @filter)
    @topics = scope.recent.includes(:user, posts: %i[user])
    post_ids = @topics.flat_map { |t| t.posts.map(&:id) }
    @liked = PostLike.where(user_id: current_user.id, post_id: post_ids).pluck(:post_id).to_set
    @participants = User.where(id: Post.where(topic_id: all.select(:id)).select(:user_id)).limit(6)
    @last_activity = all.maximum(:last_activity_at)
  end

  def create
    topic = Topic.new(page_slug: @slug, user: current_user, title: params[:title].to_s.strip, last_activity_at: Time.current)
    post = topic.posts.build(user: current_user, body: params[:body].to_s.strip)
    saved = Topic.transaction { (topic.save && post.save) || raise(ActiveRecord::Rollback) }
    if saved
      redirect_to wiki_discussion_path(@slug, anchor: "topic-#{topic.id}"), notice: "Topic started."
    else
      redirect_to wiki_discussion_path(@slug), alert: (topic.errors.full_messages + post.errors.full_messages).to_sentence
    end
  end

  def update
    topic = Topic.find(params[:id])
    return head(:forbidden) unless topic.user_id == current_user.id || current_user.editor?
    attrs = {}
    attrs[:status] = params[:status] if Topic::STATUSES.include?(params[:status])
    attrs[:pinned] = params[:pinned] == "1" if params.key?(:pinned) && current_user.editor?
    topic.update(attrs) if attrs.any?
    redirect_back fallback_location: wiki_discussion_path(topic.page_slug), status: :see_other
  end

  def destroy
    return head(:forbidden) unless current_user.admin?
    topic = Topic.find(params[:id])
    topic.destroy
    redirect_to wiki_discussion_path(topic.page_slug), notice: "Topic deleted.", status: :see_other
  end

  private

  def set_context
    @slug = params[:slug]
    @page = @slug == MAIN_PAGE ? nil : Wiki.find!(@slug)
    @page_title = @page ? @page.title : "Main Page"
  end
end

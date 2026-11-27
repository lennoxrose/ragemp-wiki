class PostsController < ApplicationController
  def create
    topic = Topic.find(params[:topic_id])
    post = topic.posts.build(user: current_user, body: params[:body].to_s.strip, parent: topic.root_post)
    if post.save
      redirect_to wiki_discussion_path(topic.page_slug, anchor: "post-#{post.id}"), status: :see_other
    else
      redirect_to wiki_discussion_path(topic.page_slug, anchor: "topic-#{topic.id}"), alert: post.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def like
    post = Post.find(params[:id])
    post.toggle_like(current_user)
    redirect_back fallback_location: wiki_discussion_path(post.topic.page_slug), status: :see_other
  end

  def destroy
    post = Post.find(params[:id])
    return head(:forbidden) unless current_user.admin? || post.user_id == current_user.id
    topic = post.topic
    if post.parent_id.nil?
      topic.destroy # removing the opening post removes the whole topic
    else
      post.destroy
      topic.touch_activity!
    end
    redirect_to wiki_discussion_path(topic.page_slug), status: :see_other
  end
end

class AccountsController < ApplicationController
  include ProfileData

  def show
    load_profile(current_user)
    @tokens = current_user.api_tokens.order(created_at: :desc)
    @new_token = flash[:new_token]
    @others = User.active.where.not(id: current_user.id).order(last_seen_at: :desc).limit(3)
  end

  def contributions
    @topics = Topic.where(user_id: current_user.id).order(created_at: :desc).limit(100)
    @posts = Post.where(user_id: current_user.id).includes(:topic).order(created_at: :desc).limit(100)
  end
end

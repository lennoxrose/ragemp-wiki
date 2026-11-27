class SettingsController < ApplicationController
  before_action :load_sessions, only: :show

  def show; end

  def update_profile
    user = current_user
    user.assign_attributes(params.permit(:display_name, :username, :bio))
    user.avatar.purge if params[:remove_avatar] == "1"
    user.banner.purge if params[:remove_banner] == "1"
    user.avatar.attach(params[:avatar]) if params[:avatar].present?
    user.banner.attach(params[:banner]) if params[:banner].present?
    if user.save
      redirect_to settings_path, notice: "Profile saved."
    else
      redirect_to settings_path, alert: user.errors.full_messages.to_sentence
    end
  end

  def update_email
    return redirect_to(settings_path, alert: "Enter your current password to change your email.") unless current_user.authenticate(params[:current_password].to_s)
    if current_user.update(email: params[:email])
      redirect_to settings_path, notice: "Email updated."
    else
      redirect_to settings_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  def update_password
    return redirect_to(settings_path, alert: "Your current password is not correct.") unless current_user.authenticate(params[:current_password].to_s)
    return redirect_to(settings_path, alert: "The new passwords do not match.") unless params[:password] == params[:password_confirmation]
    if current_user.update(password: params[:password])
      current_user.user_sessions.where.not(id: current_session.id).destroy_all # other devices must sign in again
      redirect_to settings_path, notice: "Password updated. Other devices were signed out."
    else
      redirect_to settings_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  def update_notifications
    keys = %w[notify_replies notify_mentions notify_announcements notify_digest]
    current_user.update_preferences(keys.index_with { |k| params[k] == "1" })
    redirect_to settings_path(anchor: "notifications"), notice: "Notification settings saved."
  end

  def destroy_session
    session_row = current_user.user_sessions.find(params[:id])
    return redirect_to(settings_path) if session_row.id == current_session.id
    session_row.destroy
    redirect_to settings_path(anchor: "sessions"), notice: "Device signed out."
  end

  def destroy_other_sessions
    current_user.user_sessions.where.not(id: current_session.id).destroy_all
    redirect_to settings_path(anchor: "sessions"), notice: "Signed out of all other devices."
  end

  def destroy
    return redirect_to(settings_path, alert: "Password is not correct.") unless current_user.authenticate(params[:current_password].to_s)
    if current_user.admin? && User.admins.active.count <= 1
      return redirect_to(settings_path, alert: "You are the only administrator. Make someone else an administrator first.")
    end
    user = current_user
    sign_out
    user.destroy
    redirect_to login_path, notice: "Your account was deleted."
  end

  private

  def load_sessions
    @sessions = current_user.user_sessions.order(last_active_at: :desc)
  end
end

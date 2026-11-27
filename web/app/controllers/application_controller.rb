class ApplicationController < ActionController::Base
  helper_method :current_user, :signed_in?, :current_session

  before_action :require_login
  before_action :record_activity

  rescue_from ActiveRecord::RecordNotFound do
    render "errors/not_found", status: :not_found, layout: signed_in? ? "application" : "auth"
  end

  private

  def current_session
    return @current_session if defined?(@current_session)
    @current_session = UserSession.for(session[:sid])
  end

  def current_user
    return @current_user if defined?(@current_user)
    user = current_session&.user
    @current_user = user && !user.disabled? ? user : nil
  end

  def signed_in? = current_user.present?

  def require_login
    return if signed_in?
    session[:return_to] = request.fullpath if request.get? && !request.xhr?
    redirect_to login_path
  end

  def sign_in(user)
    reset_session
    session[:sid] = UserSession.start(user, request)
    user.update_column(:last_seen_at, Time.current)
  end

  def sign_out
    current_session&.destroy
    reset_session
  end

  def record_activity
    return unless signed_in? && current_session
    current_session.update_column(:last_active_at, Time.current) if current_session.last_active_at < 1.minute.ago
    current_user.update_column(:last_seen_at, Time.current) if current_user.last_seen_at.nil? || current_user.last_seen_at < 5.minutes.ago
  end

  def find_page!
    @page = Wiki.find!(params[:slug])
  end
end

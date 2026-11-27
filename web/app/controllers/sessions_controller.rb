class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new create]
  include Turnstile
  layout "auth"

  def new
    redirect_to root_path if signed_in?
  end

  def create
    account = User.find_by(email: params[:email].to_s.strip.downcase)
    user = account&.authenticate(params[:password].to_s)
    if user.blank?
      LoginAttempt.record("wrong_password", account)
      flash.now[:error] = "Invalid email or password"
      render :new, status: :unprocessable_content
    elsif user.disabled?
      LoginAttempt.record("disabled", user)
      flash.now[:error] = "This account has been disabled. Ask an administrator for help."
      render :new, status: :forbidden
    else
      LoginAttempt.record("success", user)
      return_to = session[:return_to]
      sign_in(user)
      redirect_to(return_to.presence || root_path)
    end
  end

  def destroy
    sign_out
    redirect_to login_path
  end
end

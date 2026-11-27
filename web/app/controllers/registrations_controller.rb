class RegistrationsController < ApplicationController
  skip_before_action :require_login
  include Turnstile
  layout "auth"

  def new
    redirect_to root_path if signed_in?
  end

  def create
    invite = InviteCode.available.find_by(code: params[:invite_code].to_s.strip.upcase)
    return reject("Invalid invite code") unless invite

    user = User.new(email: params[:email], password: params[:password])
    # Creating the user and claiming the code succeed or fail together.
    registered = InviteCode.transaction { (user.save && invite.claim(user)) || raise(ActiveRecord::Rollback) }

    if registered
      sign_in(user)
      redirect_to root_path
    else
      reject(user.errors.full_messages.to_sentence.presence || "Invalid invite code")
    end
  end

  private

  def reject(message)
    flash.now[:error] = message
    render :new, status: :unprocessable_content
  end
end

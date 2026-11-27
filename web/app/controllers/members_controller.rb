class MembersController < ApplicationController
  include ProfileData

  def show
    user = User.active.find_by!(username: params[:username])
    return redirect_to account_path if user == current_user
    load_profile(user)
  end
end

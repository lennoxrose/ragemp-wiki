module Admin
  # Only administrators can create or revoke invite codes (this whole namespace requires the admin role).
  class InvitesController < BaseController
    def create
      invite = InviteCode.create!(created_by: current_user)
      log_event("created invite code #{invite.code}")
      redirect_to admin_users_path, notice: "Invite code #{invite.code} created. Send it to the person you want to invite; it works once."
    end

    def destroy
      invite = InviteCode.available.find(params[:id])
      invite.revoke!
      log_event("revoked invite code #{invite.code}")
      redirect_to admin_users_path, notice: "Invite code #{invite.code} revoked.", status: :see_other
    end
  end
end

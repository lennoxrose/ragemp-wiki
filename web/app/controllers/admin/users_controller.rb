module Admin
  class UsersController < BaseController
    PER_PAGE = 10
    before_action :find_user, only: %i[update destroy disable enable reset_password]

    def index
      @filter = params[:filter].presence_in(%w[admin editor member disabled])
      scope = User.order(created_at: :desc)
      scope = case @filter
              when nil then scope
              when "disabled" then scope.disabled
              else scope.where(role: @filter)
              end
      if params[:q].present?
        like = "%#{User.sanitize_sql_like(params[:q].strip)}%"
        scope = scope.where("email LIKE :q OR username LIKE :q OR display_name LIKE :q", q: like)
      end
      @counts = { all: User.count, admin: User.admins.count, editor: User.where(role: "editor").count, member: User.where(role: "member").count, disabled: User.disabled.count }
      @total = scope.count
      @pages = [(@total / PER_PAGE.to_f).ceil, 1].max
      @current = [[params[:page].to_i, 1].max, @pages].min
      @users = scope.offset((@current - 1) * PER_PAGE).limit(PER_PAGE)
      @invites = InviteCode.order(id: :desc).includes(:created_by, :used_by).limit(6)
      @unused_invites = InviteCode.available.count
      @events = AdminEvent.recent.includes(:actor)
      @temp_password = flash[:temp_password]
    end

    def update
      role = params[:role].to_s
      return redirect_back_with("Unknown role.", alert: true) unless User::ROLES.include?(role)
      return redirect_back_with("You are the only administrator. Make someone else an administrator first.", alert: true) if @user.admin? && role != "admin" && last_admin?(@user)
      @user.update!(role: role)
      log_event("changed the role of #{@user.name} to #{User::ROLE_LABELS[role]}")
      redirect_back_with("#{@user.name} is now #{User::ROLE_LABELS[role]}.")
    end

    def disable
      return redirect_back_with("You cannot disable your own account.", alert: true) if @user == current_user
      return redirect_back_with("You cannot disable the only administrator.", alert: true) if @user.admin? && last_admin?(@user)
      @user.disable!
      @user.user_sessions.destroy_all
      log_event("disabled #{@user.name}")
      redirect_back_with("#{@user.name} was disabled and signed out.")
    end

    def enable
      @user.enable!
      log_event("enabled #{@user.name}")
      redirect_back_with("#{@user.name} can sign in again.")
    end

    def reset_password
      temp = SecureRandom.alphanumeric(12)
      @user.update!(password: temp)
      @user.user_sessions.destroy_all
      log_event("reset the password of #{@user.name}")
      flash[:temp_password] = { "name" => @user.name, "value" => temp }
      redirect_to admin_users_path
    end

    def destroy
      return redirect_back_with("You cannot delete your own account here. Use your account settings.", alert: true) if @user == current_user
      return redirect_back_with("You cannot delete the only administrator.", alert: true) if @user.admin? && last_admin?(@user)
      name = @user.name
      @user.destroy
      log_event("deleted the account of #{name}")
      redirect_back_with("#{name} was deleted.")
    end

    private

    def find_user = (@user = User.find(params[:id]))
    def last_admin?(user) = User.admins.active.where.not(id: user.id).none?

    def redirect_back_with(message, alert: false)
      redirect_back fallback_location: admin_users_path, **(alert ? { alert: message } : { notice: message }), status: :see_other
    end
  end
end

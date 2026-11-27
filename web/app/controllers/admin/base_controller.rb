module Admin
  # The admin panel does not exist for anyone who is not a signed-in administrator: they get the same
  # "not found" as for an address that was never defined. No redirect to the login page, no 403, no flash.
  # The check runs first (before login and CSRF handling) so no other response can give the panel away.
  class BaseController < ApplicationController
    prepend_before_action :hide_from_non_admins
    skip_before_action :require_login
    layout "admin"

    private

    def hide_from_non_admins
      return if current_user&.admin?
      raise ActionController::RoutingError, "No route matches [#{request.request_method}] #{request.path.inspect}"
    end

    def log_event(action) = AdminEvent.log(current_user, action)
  end
end

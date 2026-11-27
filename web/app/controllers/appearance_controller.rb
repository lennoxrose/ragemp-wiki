class AppearanceController < ApplicationController
  def update
    attrs = params.permit(:text_size, :page_width).to_h
    attrs.delete("text_size") unless %w[small standard large].include?(attrs["text_size"])
    attrs.delete("page_width") unless %w[standard wide].include?(attrs["page_width"])
    current_user.update_preferences(attrs)
    redirect_back fallback_location: root_path, status: :see_other
  end
end

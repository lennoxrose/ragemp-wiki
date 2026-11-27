class MapController < ApplicationController
  def show
    @focus = Wiki.find(params[:focus])
    @local = @focus.present? && params[:local] == "1"
  end
end

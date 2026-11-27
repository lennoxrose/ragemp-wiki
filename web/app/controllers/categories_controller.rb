class CategoriesController < ApplicationController
  PER_PAGE = 150

  def show
    @name = params[:name]
    all = Wiki.library.in_category(@name)
    raise ActiveRecord::RecordNotFound if all.empty?

    @letters = all.map { |p| letter_for(p.title) }.uniq.sort
    @letter = params[:letter].presence_in(@letters)
    scope = @letter ? all.select { |p| letter_for(p.title) == @letter } : all
    @total = all.size
    @pages_count = (scope.size / PER_PAGE.to_f).ceil
    @current = [[params[:page].to_i, 1].max, [@pages_count, 1].max].min
    @pages = scope.slice((@current - 1) * PER_PAGE, PER_PAGE)
    @shown = scope.size
  end

  private

  def letter_for(title) = title[0].to_s.upcase.match?(/[A-Z]/) ? title[0].upcase : "#"
end

# The wiki is the Markdown mirror that wikisync writes to dist/. Nothing from it is copied into the database.
module Wiki
  module_function

  def library = Library.instance
  def root = Rails.configuration.x.wiki_root
  def slugify(title) = title.to_s.strip.tr(" ", "_")
  def find(slug) = library.page(slug.to_s)
  def find!(slug) = find(slug) || raise(ActiveRecord::RecordNotFound, "No wiki page #{slug}")
  def reload! = library.reload!
end

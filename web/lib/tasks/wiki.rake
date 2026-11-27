namespace :wiki do
  desc "Show what the web panel reads from the wiki folder"
  task stats: :environment do
    lib = Wiki.library
    puts "folder: #{Wiki.root}"
    puts "pages: #{lib.count} in #{lib.categories.size} categories"
    puts "links: #{lib.graph["out"].values.sum(&:size)}"
  end
end

namespace :users do
  desc "Create or promote an administrator: rake users:admin EMAIL=you@example.com PASSWORD=secret123"
  task admin: :environment do
    email = ENV.fetch("EMAIL") { abort "EMAIL is required" }
    user = User.find_or_initialize_by(email: email.strip.downcase)
    user.password = ENV["PASSWORD"] if ENV["PASSWORD"].present?
    abort "PASSWORD is required for a new account" if user.new_record? && user.password.blank?
    user.role = "admin"
    user.save!
    puts "#{user.email} is now an administrator (username @#{user.username})"
  end
end

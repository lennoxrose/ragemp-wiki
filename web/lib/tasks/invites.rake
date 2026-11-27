namespace :invites do
  desc "Create invite codes: rake invites:create COUNT=3 BY=creator@example.com (both optional)"
  task create: :environment do
    creator = User.find_by!(email: ENV["BY"].strip.downcase) if ENV["BY"].present?
    ENV.fetch("COUNT", "1").to_i.times { puts InviteCode.create!(created_by: creator).code }
  end

  desc "List invite codes with who created and used them"
  task list: :environment do
    InviteCode.includes(:created_by, :used_by).order(:id).each do |i|
      puts [i.code, "created #{i.created_at.to_date} by #{i.created_by&.email || 'cli'}",
            i.used_by ? "used #{i.used_at.to_date} by #{i.used_by.email}" : "unused"].join("  ")
    end
  end
end

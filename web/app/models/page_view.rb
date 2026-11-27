class PageView < ApplicationRecord
  belongs_to :user, optional: true

  def self.record(slug, user)
    create!(page_slug: slug, user: user, created_at: Time.current)
  end
end

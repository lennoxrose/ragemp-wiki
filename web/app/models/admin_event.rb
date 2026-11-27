class AdminEvent < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true

  def self.log(actor, action)
    create!(actor: actor, action: action, created_at: Time.current)
  end

  scope :recent, -> { order(created_at: :desc).limit(8) }
end

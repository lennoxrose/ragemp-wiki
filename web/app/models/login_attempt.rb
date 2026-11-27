class LoginAttempt < ApplicationRecord
  belongs_to :user, optional: true

  OUTCOMES = %w[success wrong_password disabled].freeze

  def self.record(outcome, user = nil)
    create!(outcome: outcome, user: user, created_at: Time.current)
  end
end

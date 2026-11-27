class InviteCode < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :used_by, class_name: "User", optional: true

  scope :available, -> { where(used_by_id: nil, revoked_at: nil) }
  scope :unused, -> { available }

  before_validation(on: :create) { self.code ||= SecureRandom.alphanumeric(10).upcase }
  validates :code, presence: true, uniqueness: true

  def used? = used_by_id.present?
  def revoked? = revoked_at.present?
  def status = revoked? ? "Revoked" : used? ? "Used" : "Unused"
 
  # Marks the code used by +user+. False if someone else claimed it first.
  def claim(user)
    with_lock { used_by_id.nil? && revoked_at.nil? && update!(used_by: user, used_at: Time.current) }
  end

  def revoke! = update!(revoked_at: Time.current)
end

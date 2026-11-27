class SearchLog < ApplicationRecord
  belongs_to :user, optional: true
end

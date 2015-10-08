class UserCard < ActiveRecord::Base
  belongs_to :user
  belongs_to :card
  
  scope :with_cards, ->(cards){ where(card_id: cards) }
end

class Card < ActiveRecord::Base
  belongs_to :user
  
  scope :hello_card, ->{ where phrase: 'hello' }
end

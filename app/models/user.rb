class User < ActiveRecord::Base
  has_many :user_cards
  has_many :cards, through: :user_cards
  
  def with_hello_card
    
    #eager loading all associated cards: 
    User.joins(:cards).includes(:cards).all
    
    #use joins, return users who have the phrase with 'hello'
    User.joins(:cards).where(cards: {phrase: 'hello'})

    #use joins, return users who have the phrase with 'hello' and also eager loading
    #all cards
    User.joins(:cards).where(cards: {phrase: 'hello'}).preload(:cards)
    
    #use merge, return users who have the phrase with 'hello' and also 
    #eager loading those cards
    User.joins(:cards).merge(Card.hello_card).includes(:cards)
    
    #user third model: use IN 
    #return users who have the phrase with 'hello' and also 
    #eager loading those cards
    cards = Card.hello_card
    User.joins(:user_cards).merge(UserCard.with_cards(Card.hello_card))
  end
end

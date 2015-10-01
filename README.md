About multi-tables queries
===========================
I am going to summarize some methods like includes, joins, merge, preload and eager_load. 

includes
=====================

We all konw the "N+1" issue: Whenever we are displaying a record along with an associated collection of records, we will have a so-called N+1 select problem.
We can recognize the problem by a series of many SELECT statements, with the only difference being the value of the primary key. 

'User.all' will retrieve all of the User objects from the database, but then the very next line will make an additional request for each User to retrieve 
the corresponding Card objects. To make matters worse, this code is then making even more database requests in order to retrieve the associated object of 
each Card if it has.


	class User < ActiveRecord::Base
	  has_many :cards
	end

	class Card < ActiveRecord::Base
	  belongs_to :user
	end

  	def index
    	@users = User.all
  	end
  
  	User Load (0.7ms)  SELECT "users".* FROM "users"
  	Card Load (0.7ms)  SELECT "cards".* FROM "cards" WHERE "cards"."user_id" = ?  [["user_id", 1]]
  	Card Load (0.1ms)  SELECT "cards".* FROM "cards" WHERE "cards"."user_id" = ?  [["user_id", 2]]
  
This can all be avoided by changing the first line in the method to:
	@users = User.includes(:cards).all

This tells ActiveRecord to retrieve the corresponding Card records from the database immediately after the initial request for all users, 
thereby reducing the number of database requests to just 2.

Now we actually can see 2 queries: 

  	User Load (1.2ms)  SELECT "users".* FROM "users"
  	Card Load (0.7ms)  SELECT "cards".* FROM "cards" WHERE "cards"."user_id" IN (1, 2)
  
joins
=================

If we joins the table, then it’s one query with an INNER JOIN:

	 SQL (1.2ms)  SELECT "users"."id" AS t0_r0, "users"."name" AS t0_r1, "users"."created_at" AS t0_r2, "users"."updated_at" AS t0_r3, 
	 "cards"."id" AS t1_r0, "cards"."phrase" AS t1_r1, "cards"."user_id" AS t1_r2, "cards"."created_at" AS t1_r3, "cards"."updated_at" AS t1_r4 
	 FROM "users" INNER JOIN "cards" ON "cards"."user_id" = "users"."id"

Now ActiveRecord is giving us the users and the eager loading through one SQL query. It's obviously faster and neater. 

With Conditions
=================

From Rails guild: 

	When we specify conditions on the eager loaded associations just like joins, the recommended way is to use joins instead.
	However if you must do this, you may use where as you would normally.

	@users = User.includes(:cards).where(cards: {phrase: 'hello'})
	SQL (1.0ms)  SELECT "users"."id" AS t0_r0, "users"."name" AS t0_r1, "users"."created_at" AS t0_r2, "users"."updated_at" AS t0_r3, "cards"."id" 
	AS t1_r0, "cards"."phrase" AS t1_r1, "cards"."user_id" AS t1_r2, "cards"."created_at" AS t1_r3, "cards"."updated_at" AS t1_r4 FROM "users" 
	LEFT OUTER JOIN "cards" ON "cards"."user_id" = "users"."id" WHERE "cards"."phrase" = ?  [["phrase", "hello"]]
	
Now includes delegates the job to #eager_load with 1 query which contains a LEFT OUTER JOIN whereas the joins method would generate 
one using the INNER JOIN function instead: 
	
	@users = User.joins(:cards).where(cards: {phrase: 'hello'})
	User Load (0.2ms)  SELECT "users".* FROM "users" INNER JOIN "cards" ON "cards"."user_id" = "users"."id" WHERE "cards"."phrase" = ?  [["phrase", "hello"]]
	(but when we get access to users' associated object in the view like cards, it will do another query: 
	and it will get all of the associated card records ignoring the where conditions: The card will be loaded again: 
		Card Load (0.1ms)  SELECT "cards".* FROM "cards" WHERE "cards"."user_id" = ?  [["user_id", 1]])
		
If we still wanna just 1 query and also the card records under the condition, we still need to use includes. 
We can complete it like: 

	 @users = User.joins(:cards).where(cards: {phrase: 'hello'}).includes(:cards)
	 SQL (0.3ms)  SELECT "users"."id" AS t0_r0, "users"."name" AS t0_r1, "users"."created_at" AS t0_r2, "users"."updated_at" AS t0_r3, "cards"."id" 
	 AS t1_r0, "cards"."phrase" AS t1_r1, "cards"."user_id" AS t1_r2, "cards"."created_at" AS t1_r3, "cards"."updated_at" AS t1_r4 FROM "users" 
	 INNER JOIN "cards" ON "cards"."user_id" = "users"."id" WHERE "cards"."phrase" = ?  [["phrase", "hello"]]


There's another thing: 

Using where like this will only work when you pass it a Hash. For SQL-fragments you need use references to force joined tables:

	[21] pry(main)> User.includes(:cards).where("cards.phrase = 'hello'").references(:cards)
	
  	SQL (0.7ms)  SELECT "users"."id" AS t0_r0, "users"."name" AS t0_r1, "users"."created_at" AS t0_r2, "users"."updated_at" AS t0_r3, "cards"."id" 
  	AS t1_r0, "cards"."phrase" AS t1_r1, "cards"."user_id" AS t1_r2, "cards"."created_at" AS t1_r3, "cards"."updated_at" AS t1_r4 FROM "users" 
  	LEFT OUTER JOIN "cards" ON "cards"."user_id" = "users"."id" WHERE (cards.phrase = 'hello')
	=> [#<User:0x007faabf033df8 id: 1, name: "jeff", created_at: Thu, 01 Oct 2015 06:18:18 UTC +00:00, updated_at: Thu, 01 Oct 2015 06:18:18 UTC +00:00>]


merge:
==================
I just found the merge method can do the similar thing: 

This is the explaination from the Rails API: 

    merge(other)
    Merges in the conditions from other, if other is an ActiveRecord::Relation. Returns an array representing the intersection of the resulting records 
    with other, if other is an array.

	Post.where(published: true).joins(:comments).merge( Comment.where(spam: false) )
	# Performs a single join query with both where conditions.

	recent_posts = Post.order('created_at DESC').first(5)
	Post.where(published: true).merge(recent_posts)
	# Returns the intersection of all published posts with the 5 most recently created posts.
	# (This is just an example. You'd probably want to do this with a single query!)
	
	Procs will be evaluated by merge:

	Post.where(published: true).merge(-> { joins(:comments) })
	# => Post.where(published: true).joins(:comments)
	This is mainly intended for sharing common conditions between multiple associations.
	
If I define a scope in Card model: 

	scope :hello_card, ->{ where phrase: 'hello' }
	
Then I can use it in merge, instead of using the where statement: It's quite clean. 

	@users = User.joins(:cards).merge(Card.hello_card)
	
	SELECT "users".* FROM "users" INNER JOIN "cards" ON "cards"."user_id" = "users"."id" WHERE "cards"."phrase" = ?  [["phrase", "hello"]]
	
We can also use it with includes, If we references the table, then we get one query - with a LEFT OUTER JOIN instead of an INNER JOIN. 
This tells ActiveRecord that we’ll be referencing that table in our query. 

	@users = User.includes(:cards).references(:cards).merge(Card.hello_card)

eager_load:
======================
Eager_load is using one query (with left join) to get them all.

User.eager_load(:cards).merge(Card.hello_card)

  SQL (1.2ms)  SELECT "users"."id" AS t0_r0, "users"."name" AS t0_r1, "users"."created_at" AS t0_r2, "users"."updated_at" AS t0_r3, "cards"."id" 
  AS t1_r0, "cards"."phrase" AS t1_r1, "cards"."user_id" AS t1_r2, "cards"."created_at" AS t1_r3, "cards"."updated_at" AS t1_r4 FROM "users" 
  LEFT OUTER JOIN "cards" ON "cards"."user_id" = "users"."id" WHERE "cards"."phrase" = ?  [["phrase", "hello"]]
=> [#<User:0x007faabf1d1ca0 id: 1, name: "jeff", created_at: Thu, 01 Oct 2015 06:18:18 UTC +00:00, updated_at: Thu, 01 Oct 2015 06:18:18 UTC +00:00>]


preload:
=======================
	
    User.preload(:cards)
    User Load (1.2ms)  SELECT "users".* FROM "users"
    Card Load (0.5ms)  SELECT "cards".* FROM "cards" WHERE "cards"."user_id" IN (1, 2)
    => [#<User:0x007faabf089460 id: 1, name: "jeff", created_at: Thu, 01 Oct 2015 06:18:18 UTC +00:00, updated_at: Thu, 01 Oct 2015 06:18:18 UTC +00:00>,
    #<User:0x007faabf089280 id: 2, name: "emma", created_at: Thu, 01 Oct 2015 06:19:51 UTC +00:00, updated_at: Thu, 01 Oct 2015 06:19:51 UTC +00:00>]
 
Apparently #preload behave just like #includes. 

If we use the condition on preload: it causes error: 

	[4] pry(main)> User.pre_load(:cards).where(cards: {phrase: 'hello'})
	NoMethodError: undefined method `pre_load' for #<Class:0x007faabf42d7b0>

If we need only users who have 'hello' card but also eager load the cards, we can use the includes. 
But If we need only users who have 'hello' card but also eager load all of the cards, we can use preload: 

 	@users = User.joins(:cards).where(cards: {phrase: 'hello'}).preload(:cards)
    User Load (0.2ms)  SELECT "users".* FROM "users" INNER JOIN "cards" ON "cards"."user_id" = "users"."id" WHERE "cards"."phrase" = ?  [["phrase", "hello"]]
    Card Load (0.3ms)  SELECT "cards".* FROM "cards" WHERE "cards"."user_id" IN (1)
  
  

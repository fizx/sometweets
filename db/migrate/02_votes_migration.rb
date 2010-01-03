class VotesMigration < ActiveRecord::Migration
  def self.up
    create_table :votes do |t|
      t.integer :user_id
      t.string :tweet_guid
      t.string :tweeter
      t.string :content
      t.integer :value
    end  
    add_index :votes, :user_id
    add_index :votes, :tweet_guid
  end

  def self.down
    drop_table :users
  end
end

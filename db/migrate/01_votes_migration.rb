class VotesMigration < ActiveRecord::Migration
  def self.up
    create_table :votes do |t|
      t.integer :user_handle
      t.string :tweet_guid
      t.string :speaker_handle
      t.string :content
      t.integer :value
    end  
    add_index :votes, :user_handle
    add_index :votes, :tweet_guid
  end

  def self.down
    drop_table :users
  end
end

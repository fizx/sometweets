class UsersMigration < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string :handle
      t.text :classifier
    end  
    add_index :users, :handle
  end

  def self.down
    drop_table :users
  end
end

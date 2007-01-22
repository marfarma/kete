class AddStillImages < ActiveRecord::Migration
  def self.up
    create_table :still_images do |t|
      t.column :title, :string, :null => false
      t.column :description, :text
      t.column :created_at, :datetime, :null => false
      t.column :updated_at, :datetime, :null => false
    end
  end

  def self.down
    drop_table :still_images
  end
end
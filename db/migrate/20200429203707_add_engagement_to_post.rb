class AddEngagementToPost < ActiveRecord::Migration[6.0]
  def change
    add_column :posts, :engagement, :float
  end
end

class CreatePosts < ActiveRecord::Migration[6.0]
  def change
    create_table :posts do |t|
      t.text :body
      t.references :user, foreign_key: true
      t.integer :likes
      t.integer :comments
      t.string :shortcode
      t.string :ig

      t.timestamps
    end
  end
end

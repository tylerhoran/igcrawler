class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :country
      t.integer :followers
      t.string :ig

      t.timestamps
    end
  end
end

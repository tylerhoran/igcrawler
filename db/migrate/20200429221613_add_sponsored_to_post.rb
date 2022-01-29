class AddSponsoredToPost < ActiveRecord::Migration[6.0]
  def change
    add_column :posts, :sponsored, :boolean, defaut: false
  end
end

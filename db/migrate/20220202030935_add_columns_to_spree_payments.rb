class AddColumnsToSpreePayments < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_payments, :lease_id, :string
    add_column :spree_payments, :lease_number, :string
    add_column :spree_payments, :checkout_token, :string
  end
end

class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users, id: :uuid do |t|
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.integer :role, null: false, default: 0 # operator

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end

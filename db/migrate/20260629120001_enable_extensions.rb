class EnableExtensions < ActiveRecord::Migration[7.2]
  def change
    enable_extension "pgcrypto" # gen_random_uuid() for UUID primary keys
    enable_extension "citext"   # case-insensitive email
  end
end

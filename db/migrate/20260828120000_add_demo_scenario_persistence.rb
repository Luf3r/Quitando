class AddDemoScenarioPersistence < ActiveRecord::Migration[8.1]
  def up
    execute "SET LOCAL lock_timeout = '2s'"

    add_column :users, :demo_account, :boolean
    change_column_default :users, :demo_account, false
    execute "UPDATE users SET demo_account = FALSE WHERE demo_account IS NULL"
    add_check_constraint :users, "demo_account IS NOT NULL", name: "users_demo_account_not_null", validate: false
    validate_check_constraint :users, name: "users_demo_account_not_null"
    change_column_null :users, :demo_account, false
    remove_check_constraint :users, name: "users_demo_account_not_null"

    create_table :demo_scenarios, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :key, null: false
      t.integer :version, null: false
      t.datetime :installed_at, null: false
      t.datetime :last_reset_at, null: false
      t.timestamps
    end
    add_index :demo_scenarios, :key, unique: true
  end

  def down
    execute "SET LOCAL lock_timeout = '2s'"

    drop_table :demo_scenarios
    remove_column :users, :demo_account
  end
end

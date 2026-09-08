class AddDemoScenarioPersistence < ActiveRecord::Migration[8.1]
  def up
    execute "SET LOCAL lock_timeout = '2s'"

    add_column :users, :demo_account, :boolean, default: false, null: false

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

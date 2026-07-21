class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.string :currency_code, null: false
      t.bigint :financial_state_version, null: false, default: 0
      t.datetime :archived_at
      t.timestamps
    end

    add_check_constraint :groups, "financial_state_version >= 0", name: "groups_financial_state_version_nonnegative"
  end
end

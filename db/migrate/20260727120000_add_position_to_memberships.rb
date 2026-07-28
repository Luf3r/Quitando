class AddPositionToMemberships < ActiveRecord::Migration[8.1]
  def up
    add_column :memberships, :position, :integer

    execute <<~SQL
      UPDATE memberships
      SET position = ordered.position
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY group_id ORDER BY created_at, id) - 1 AS position
        FROM memberships
      ) AS ordered
      WHERE memberships.id = ordered.id
    SQL

    change_column_null :memberships, :position, false
    add_check_constraint :memberships, "position >= 0", name: "memberships_position_nonnegative"
    add_index :memberships, %i[group_id position], unique: true
  end

  def down
    remove_index :memberships, column: %i[group_id position]
    remove_check_constraint :memberships, name: "memberships_position_nonnegative"
    remove_column :memberships, :position
  end
end

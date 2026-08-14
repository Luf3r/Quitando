class AddGroupInvitationsAndGroupContracts < ActiveRecord::Migration[8.1]
  def up
    with_lock_timeout do
      add_check_constraint :groups, "currency_code = 'BRL'", name: "groups_currency_code_brl"
      add_check_constraint :groups, "btrim(name) <> ''", name: "groups_name_nonblank"

      remove_index :memberships, column: %i[group_id position]
      add_unique_constraint :memberships, %i[group_id position], deferrable: :immediate, name: "memberships_group_position_unique"

      create_table :group_invitations, id: :uuid, default: -> { "uuidv7()" } do |t|
        t.references :group, null: false, type: :uuid, foreign_key: true
        t.references :invited_user, null: false, type: :uuid, foreign_key: { to_table: :users }
        t.references :invited_by_user, null: false, type: :uuid, foreign_key: { to_table: :users }
        t.string :status, null: false
        t.datetime :expires_at, null: false
        t.datetime :accepted_at
        t.datetime :declined_at
        t.datetime :revoked_at
        t.datetime :expired_at
        t.timestamps
      end
      add_index :group_invitations, %i[group_id invited_user_id], unique: true,
        where: "status = 'pending'", name: "index_group_invitations_one_pending_per_user"
      add_check_constraint :group_invitations,
        "status IN ('pending', 'accepted', 'declined', 'revoked', 'expired')",
        name: "group_invitations_status_valid"
      add_check_constraint :group_invitations, <<~SQL.squish, name: "group_invitations_audit_metadata_matches_status"
        (status = 'pending' AND accepted_at IS NULL AND declined_at IS NULL AND revoked_at IS NULL AND expired_at IS NULL)
        OR (status = 'accepted' AND accepted_at IS NOT NULL AND declined_at IS NULL AND revoked_at IS NULL AND expired_at IS NULL)
        OR (status = 'declined' AND accepted_at IS NULL AND declined_at IS NOT NULL AND revoked_at IS NULL AND expired_at IS NULL)
        OR (status = 'revoked' AND accepted_at IS NULL AND declined_at IS NULL AND revoked_at IS NOT NULL AND expired_at IS NULL)
        OR (status = 'expired' AND accepted_at IS NULL AND declined_at IS NULL AND revoked_at IS NULL AND expired_at IS NOT NULL)
      SQL
    end
  end

  def down
    with_lock_timeout do
      drop_table :group_invitations
      remove_unique_constraint :memberships, name: "memberships_group_position_unique"
      add_index :memberships, %i[group_id position], unique: true
      remove_check_constraint :groups, name: "groups_name_nonblank"
      remove_check_constraint :groups, name: "groups_currency_code_brl"
    end
  end

  private

  def with_lock_timeout
    previous = connection.select_value("SHOW lock_timeout")
    execute "SET lock_timeout = '2s'"
    yield
  ensure
    execute "SET lock_timeout = #{connection.quote(previous)}" if previous
  end
end

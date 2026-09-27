class AddNameToUsers < ActiveRecord::Migration[8.1]
  CANONICAL_DEMO_NAMES = {
    "ana@demo.quitando.test" => "Ana",
    "bruno@demo.quitando.test" => "Bruno",
    "carla@demo.quitando.test" => "Carla",
    "diego@demo.quitando.test" => "Diego"
  }.freeze

  def up
    with_lock_timeout do
      add_column :users, :name, :string, limit: 80
      reconcile_canonical_demo_names!
      refuse_users_without_name!
      add_check_constraint :users, "btrim(name) <> ''", name: "users_name_nonblank", validate: false
      validate_check_constraint :users, name: "users_name_nonblank"
      change_column_null :users, :name, false
    end
  end

  def down
    with_lock_timeout do
      remove_check_constraint :users, name: "users_name_nonblank"
      remove_column :users, :name
    end
  end

  private

  def reconcile_canonical_demo_names!
    values = CANONICAL_DEMO_NAMES.map do |email, name|
      "(#{connection.quote(email)}, #{connection.quote(name)})"
    end.join(", ")

    execute <<~SQL
      UPDATE users
      SET name = canonical.name
      FROM (VALUES #{values}) AS canonical(email, name)
      WHERE users.name IS NULL
        AND users.email = canonical.email
    SQL
  end

  def refuse_users_without_name!
    residual_count = connection.select_value("SELECT COUNT(*) FROM users WHERE name IS NULL").to_i
    return if residual_count.zero?

    raise ActiveRecord::MigrationError,
      "users.name backfill refused: #{residual_count} non-canonical user(s) remain without a name"
  end

  def with_lock_timeout
    previous = connection.select_value("SHOW lock_timeout")
    execute "SET lock_timeout = '2s'"
    yield
  ensure
    execute "SET lock_timeout = #{connection.quote(previous)}" if previous
  end
end

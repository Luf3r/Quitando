require "rails_helper"

RSpec.describe "Fase 2: contrato estrutural PostgreSQL" do
  PRIMARY_KEY_TABLES = {
    "users" => User,
    "groups" => Group,
    "memberships" => Membership,
    "expenses" => Expense,
    "expense_shares" => ExpenseShare,
    "payments" => Payment
  }.freeze

  FOREIGN_KEY_COLUMNS = {
    "memberships" => %w[group_id user_id],
    "expenses" => %w[group_id paid_by_user_id created_by_user_id voided_by_user_id replaces_expense_id],
    "expense_shares" => %w[expense_id user_id],
    "payments" => %w[group_id from_user_id to_user_id reported_by_user_id confirmed_by_user_id cancelled_by_user_id]
  }.freeze

  MONEY_COLUMNS = {
    "expenses" => "amount_cents",
    "expense_shares" => "amount_owed_cents",
    "payments" => "amount_cents"
  }.freeze

  it "declara PKs UUID v7, FKs UUID e dinheiro bigint no catálogo PostgreSQL" do
    PRIMARY_KEY_TABLES.each do |table_name, model|
      expect(model.columns_hash.fetch("id").sql_type).to eq("uuid")
      expect(column_default(table_name, "id")).to eq("uuidv7()")
    end

    FOREIGN_KEY_COLUMNS.each do |table_name, columns|
      columns.each do |column_name|
        expect(table_columns(table_name).fetch(column_name)).to eq("uuid")
        expect(connection.foreign_keys(table_name).map(&:column)).to include(column_name)
      end
    end

    MONEY_COLUMNS.each do |table_name, column_name|
      expect(table_columns(table_name).fetch(column_name)).to eq("bigint")
    end
  end

  it "faz cada factory persistida receber UUID v7 real do PostgreSQL" do
    records = [
      create(:user),
      create(:group),
      create(:membership),
      create(:expense),
      create(:expense_share),
      create(:payment)
    ]

    records.each do |record|
      expect(uuid_version(record.id)).to eq(7)
    end
  end

  it "recusa a versão financeira nula ou negativa sem validations Rails" do
    Group.insert_all!([ { name: "Casa direta", currency_code: "BRL", created_at: Time.current, updated_at: Time.current } ])

    expect(Group.find_by!(name: "Casa direta").financial_state_version).to eq(0)

    expect_postgres_error(PG::NotNullViolation) do
      insert_direct(Group, name: "Casa", currency_code: "BRL", financial_state_version: nil)
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Group, name: "Casa", currency_code: "BRL", financial_state_version: -1)
    end
  end

  it "recusa referências inexistentes em cada foreign key" do
    group = create(:group)
    user = create(:user)
    expense = create(:expense, group:, paid_by_user: user, created_by_user: user)
    from_user = create(:user)
    to_user = create(:user)

    foreign_key_cases(group:, user:, expense:, from_user:, to_user:).each do |model, attributes|
      expect_postgres_error(PG::ForeignKeyViolation) { insert_direct(model, **attributes) }
    end
  end

  it "recusa membership com FK ausente, duplicidade ou estado inválido" do
    group = create(:group)
    user = create(:user)
    create(:membership, group:, user:)

    expect_postgres_error(PG::ForeignKeyViolation) do
      insert_direct(Membership, group_id: database_uuid, user_id: user.id, role: "member", status: "active")
    end
    expect_postgres_error(PG::UniqueViolation) do
      insert_direct(Membership, group_id: group.id, user_id: user.id, role: "member", status: "active")
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Membership, group_id: group.id, user_id: user.id, role: "admin", status: "active")
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Membership, group_id: group.id, user_id: user.id, role: "member", status: "pending")
    end
  end

  it "recusa expense sem FK, valor positivo, auditoria completa ou substituição própria" do
    group = create(:group)
    user = create(:user)
    attributes = expense_attributes(group:, user:)

    expect_postgres_error(PG::ForeignKeyViolation) do
      insert_direct(Expense, **attributes.merge(group_id: database_uuid))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Expense, **attributes.merge(amount_cents: 0))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Expense, **attributes.merge(voided_at: Time.current))
    end
    expect_postgres_error(PG::CheckViolation) do
      id = database_uuid
      insert_direct(Expense, **attributes.merge(id:, replaces_expense_id: id))
    end
  end

  it "recusa share sem FK, valor positivo, posição ou par único" do
    expense = create(:expense)
    user = create(:user)
    create(:expense_share, expense:, user:)
    attributes = { expense_id: expense.id, user_id: user.id, amount_owed_cents: 100, position: 0 }

    expect_postgres_error(PG::ForeignKeyViolation) do
      insert_direct(ExpenseShare, **attributes.merge(expense_id: database_uuid))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(ExpenseShare, **attributes.merge(amount_owed_cents: 0))
    end
    expect_postgres_error(PG::NotNullViolation) do
      insert_direct(ExpenseShare, **attributes.merge(position: nil))
    end
    expect_postgres_error(PG::UniqueViolation) do
      insert_direct(ExpenseShare, **attributes)
    end
  end

  it "recusa payment com FKs, dinheiro, participantes, versão, estado e auditoria inválidos" do
    group = create(:group)
    from_user = create(:user)
    to_user = create(:user)
    attributes = payment_attributes(group:, from_user:, to_user:)

    expect_postgres_error(PG::ForeignKeyViolation) do
      insert_direct(Payment, **attributes.merge(group_id: database_uuid))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **attributes.merge(amount_cents: 0))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **attributes.merge(to_user_id: from_user.id))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **attributes.merge(source_financial_state_version: -1))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **attributes.merge(status: "processing"))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **attributes.merge(status: "confirmed"))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **attributes.merge(status: "reported", confirmed_by_user_id: to_user.id, confirmed_at: Time.current))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **attributes.merge(status: "cancelled", cancelled_by_user_id: to_user.id, cancelled_at: Time.current))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **attributes.merge(status: "reported", cancellation_reason: "motivo isolado"))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **confirmed_payment_attributes(attributes, to_user).merge(cancelled_by_user_id: from_user.id, cancelled_at: Time.current, cancellation_reason: "duplicado"))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **cancelled_payment_attributes(attributes, from_user).merge(confirmed_by_user_id: to_user.id, confirmed_at: Time.current))
    end
  end

  it "recusa chave de idempotência global repetida sem validations Rails" do
    group = create(:group)
    from_user = create(:user)
    to_user = create(:user)
    idempotency_key = database_uuid
    attributes = payment_attributes(group:, from_user:, to_user:, idempotency_key:)

    insert_direct(Payment, **attributes)

    expect_postgres_error(PG::UniqueViolation) do
      insert_direct(Payment, **attributes.merge(request_fingerprint: "outro-payload"))
    end
  end

  it "evita índices de prefixo redundantes quando há um índice composto" do
    expect(index_columns(:memberships)).not_to include([ "group_id" ])
    expect(index_columns(:expense_shares)).not_to include([ "expense_id" ])
    expect(index_columns(:payments)).not_to include([ "group_id" ])

    expect(index_columns(:memberships)).to include(%w[group_id user_id])
    expect(index_columns(:expense_shares)).to include(%w[expense_id user_id])
    expect(index_columns(:payments)).to include(%w[group_id status])
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def column_default(table_name, column_name)
    connection.select_value(<<~SQL.squish)
      SELECT pg_get_expr(defaults.adbin, defaults.adrelid)
      FROM pg_attrdef defaults
      JOIN pg_attribute attributes
        ON attributes.attrelid = defaults.adrelid AND attributes.attnum = defaults.adnum
      JOIN pg_class tables ON tables.oid = defaults.adrelid
      WHERE tables.relname = #{connection.quote(table_name)}
        AND attributes.attname = #{connection.quote(column_name)}
    SQL
  end

  def table_columns(table_name)
    connection.columns(table_name).to_h { |column| [ column.name, column.sql_type ] }
  end

  def uuid_version(id)
    connection.select_value("SELECT uuid_extract_version(#{connection.quote(id)}::uuid)")
  end

  def database_uuid
    connection.select_value("SELECT uuidv7()")
  end

  def insert_direct(model, **attributes)
    model.insert_all!([ attributes.merge(created_at: Time.current, updated_at: Time.current) ])
  end

  def expect_postgres_error(error_class, &block)
    expect do
      ApplicationRecord.transaction(requires_new: true, &block)
    end.to raise_error(ActiveRecord::StatementInvalid) { |error| expect(error.cause).to be_a(error_class) }
  end

  def expense_attributes(group:, user:)
    {
      group_id: group.id,
      paid_by_user_id: user.id,
      created_by_user_id: user.id,
      amount_cents: 100,
      description: "Mercado",
      occurred_on: Date.current
    }
  end

  def foreign_key_cases(group:, user:, expense:, from_user:, to_user:)
    missing_id = database_uuid
    payment = payment_attributes(group:, from_user:, to_user:)

    [
      [ Membership, { group_id: missing_id, user_id: user.id, role: "member", status: "active" } ],
      [ Membership, { group_id: group.id, user_id: missing_id, role: "member", status: "active" } ],
      [ Expense, expense_attributes(group:, user:).merge(group_id: missing_id) ],
      [ Expense, expense_attributes(group:, user:).merge(paid_by_user_id: missing_id) ],
      [ Expense, expense_attributes(group:, user:).merge(created_by_user_id: missing_id) ],
      [ Expense, expense_attributes(group:, user:).merge(voided_at: Time.current, voided_by_user_id: missing_id, void_reason: "correção") ],
      [ Expense, expense_attributes(group:, user:).merge(replaces_expense_id: missing_id) ],
      [ ExpenseShare, { expense_id: missing_id, user_id: user.id, amount_owed_cents: 100, position: 0 } ],
      [ ExpenseShare, { expense_id: expense.id, user_id: missing_id, amount_owed_cents: 100, position: 0 } ],
      [ Payment, payment.merge(group_id: missing_id) ],
      [ Payment, payment.merge(from_user_id: missing_id) ],
      [ Payment, payment.merge(to_user_id: missing_id) ],
      [ Payment, payment.merge(reported_by_user_id: missing_id) ],
      [ Payment, confirmed_payment_attributes(payment, missing_id) ],
      [ Payment, cancelled_payment_attributes(payment, missing_id) ]
    ]
  end

  def payment_attributes(group:, from_user:, to_user:, idempotency_key: database_uuid)
    {
      group_id: group.id,
      from_user_id: from_user.id,
      to_user_id: to_user.id,
      amount_cents: 100,
      status: "reported",
      idempotency_key:,
      request_fingerprint: SecureRandom.hex(32),
      source_financial_state_version: 0,
      reported_by_user_id: from_user.id,
      reported_at: Time.current
    }
  end

  def confirmed_payment_attributes(attributes, confirmed_by_user_id)
    attributes.merge(status: "confirmed", confirmed_by_user_id:, confirmed_at: Time.current)
  end

  def cancelled_payment_attributes(attributes, cancelled_by_user_id)
    attributes.merge(status: "cancelled", cancelled_by_user_id:, cancelled_at: Time.current, cancellation_reason: "Pagamento não realizado")
  end

  def index_columns(table_name)
    connection.indexes(table_name).map(&:columns)
  end
end

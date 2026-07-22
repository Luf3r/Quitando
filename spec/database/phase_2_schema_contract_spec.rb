require "rails_helper"

RSpec.describe "Fase 2: contrato estrutural PostgreSQL" do
  BIGINT_MAX = 9_223_372_036_854_775_807

  TABLE_COLUMNS = {
    "users" => {
      "id" => [ "uuid", false ],
      "email" => [ "character varying", false ],
      "encrypted_password" => [ "character varying", false ],
      "reset_password_token" => [ "character varying", true ],
      "reset_password_sent_at" => [ "timestamp(6) without time zone", true ],
      "remember_created_at" => [ "timestamp(6) without time zone", true ],
      "created_at" => [ "timestamp(6) without time zone", false ],
      "updated_at" => [ "timestamp(6) without time zone", false ]
    },
    "groups" => {
      "id" => [ "uuid", false ],
      "name" => [ "character varying", false ],
      "currency_code" => [ "character varying", false ],
      "financial_state_version" => [ "bigint", false ],
      "archived_at" => [ "timestamp(6) without time zone", true ],
      "created_at" => [ "timestamp(6) without time zone", false ],
      "updated_at" => [ "timestamp(6) without time zone", false ]
    },
    "memberships" => {
      "id" => [ "uuid", false ],
      "group_id" => [ "uuid", false ],
      "user_id" => [ "uuid", false ],
      "role" => [ "character varying", false ],
      "status" => [ "character varying", false ],
      "created_at" => [ "timestamp(6) without time zone", false ],
      "updated_at" => [ "timestamp(6) without time zone", false ]
    },
    "expenses" => {
      "id" => [ "uuid", false ],
      "group_id" => [ "uuid", false ],
      "paid_by_user_id" => [ "uuid", false ],
      "created_by_user_id" => [ "uuid", false ],
      "amount_cents" => [ "bigint", false ],
      "description" => [ "character varying", false ],
      "occurred_on" => [ "date", false ],
      "voided_at" => [ "timestamp(6) without time zone", true ],
      "voided_by_user_id" => [ "uuid", true ],
      "void_reason" => [ "character varying", true ],
      "replaces_expense_id" => [ "uuid", true ],
      "created_at" => [ "timestamp(6) without time zone", false ],
      "updated_at" => [ "timestamp(6) without time zone", false ]
    },
    "expense_shares" => {
      "id" => [ "uuid", false ],
      "expense_id" => [ "uuid", false ],
      "user_id" => [ "uuid", false ],
      "amount_owed_cents" => [ "bigint", false ],
      "position" => [ "integer", false ],
      "created_at" => [ "timestamp(6) without time zone", false ],
      "updated_at" => [ "timestamp(6) without time zone", false ]
    },
    "payments" => {
      "id" => [ "uuid", false ],
      "group_id" => [ "uuid", false ],
      "from_user_id" => [ "uuid", false ],
      "to_user_id" => [ "uuid", false ],
      "amount_cents" => [ "bigint", false ],
      "status" => [ "character varying", false ],
      "idempotency_key" => [ "uuid", false ],
      "request_fingerprint" => [ "character varying", false ],
      "source_financial_state_version" => [ "bigint", false ],
      "reported_by_user_id" => [ "uuid", false ],
      "reported_at" => [ "timestamp(6) without time zone", false ],
      "confirmed_by_user_id" => [ "uuid", true ],
      "confirmed_at" => [ "timestamp(6) without time zone", true ],
      "cancelled_by_user_id" => [ "uuid", true ],
      "cancelled_at" => [ "timestamp(6) without time zone", true ],
      "cancellation_reason" => [ "character varying", true ],
      "created_at" => [ "timestamp(6) without time zone", false ],
      "updated_at" => [ "timestamp(6) without time zone", false ]
    }
  }.freeze

  FOREIGN_KEYS = {
    "users" => [],
    "groups" => [],
    "memberships" => [
      [ "group_id", "groups", "id" ],
      [ "user_id", "users", "id" ]
    ],
    "expenses" => [
      [ "created_by_user_id", "users", "id" ],
      [ "group_id", "groups", "id" ],
      [ "paid_by_user_id", "users", "id" ],
      [ "replaces_expense_id", "expenses", "id" ],
      [ "voided_by_user_id", "users", "id" ]
    ],
    "expense_shares" => [
      [ "expense_id", "expenses", "id" ],
      [ "user_id", "users", "id" ]
    ],
    "payments" => [
      [ "cancelled_by_user_id", "users", "id" ],
      [ "confirmed_by_user_id", "users", "id" ],
      [ "from_user_id", "users", "id" ],
      [ "group_id", "groups", "id" ],
      [ "reported_by_user_id", "users", "id" ],
      [ "to_user_id", "users", "id" ]
    ]
  }.freeze

  UNIQUE_INDEXES = {
    "users" => [ %w[email], %w[reset_password_token] ],
    "groups" => [],
    "memberships" => [ %w[group_id user_id] ],
    "expenses" => [],
    "expense_shares" => [ %w[expense_id user_id] ],
    "payments" => [ %w[idempotency_key] ]
  }.freeze

  MONEY_COLUMNS = {
    Expense => :amount_cents,
    ExpenseShare => :amount_owed_cents,
    Payment => :amount_cents
  }.freeze

  it "prova PK real em id, tipos, nullability e default UUID v7 no catálogo", :aggregate_failures do
    expect(TABLE_COLUMNS.keys).to match_array(%w[users groups memberships expenses expense_shares payments])

    TABLE_COLUMNS.each do |table_name, expected_columns|
      expect(primary_key_columns(table_name)).to eq([ "id" ]), table_name
      expect(table_columns(table_name)).to eq(expected_columns), table_name
      expect(column_default(table_name, "id")).to eq("uuidv7()"), table_name
    end
  end

  it "prova cada FK com coluna de origem e destino exatas", :aggregate_failures do
    expect(FOREIGN_KEYS.keys).to match_array(%w[users groups memberships expenses expense_shares payments])

    FOREIGN_KEYS.each do |table_name, expected_foreign_keys|
      expect(foreign_keys(table_name)).to eq(expected_foreign_keys), table_name
    end
  end

  it "prova unicidades, índices operacionais e cobertura líder de todas as FKs", :aggregate_failures do
    UNIQUE_INDEXES.each do |table_name, expected_indexes|
      expect(unique_index_columns(table_name)).to match_array(expected_indexes), table_name
    end

    expect(index_columns(:payments)).to include(
      %w[group_id status],
      %w[reported_at],
      %w[confirmed_at]
    )

    FOREIGN_KEYS.each do |table_name, definitions|
      definitions.each do |column_name, _destination_table, _destination_column|
        expect(index_columns(table_name).any? { |columns| columns.first == column_name }).to be(true),
          "#{table_name}.#{column_name} sem índice líder"
      end
    end

    expect(index_columns(:memberships)).not_to include([ "group_id" ])
    expect(index_columns(:expense_shares)).not_to include([ "expense_id" ])
    expect(index_columns(:payments)).not_to include([ "group_id" ])
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

  it "aceita dinheiro mínimo e máximo bigint e versões zero", :aggregate_failures do
    group = create(:group)
    from_user = create(:user)
    to_user = create(:user)

    defaulted_version_group = insert_and_fetch(Group, name: "Versão padrão", currency_code: "BRL")
    expect(defaulted_version_group.financial_state_version).to eq(0)

    [ 1, BIGINT_MAX ].each_with_index do |amount_cents, index|
      expense = insert_and_fetch(
        Expense,
        **expense_attributes(group:, user: from_user).merge(
          amount_cents:,
          description: "Limite #{index}"
        )
      )
      share = insert_and_fetch(
        ExpenseShare,
        expense_id: expense.id,
        user_id: to_user.id,
        amount_owed_cents: amount_cents,
        position: index
      )
      payment = insert_and_fetch(
        Payment,
        **payment_attributes(group:, from_user:, to_user:).merge(
          amount_cents:,
          source_financial_state_version: 0
        )
      )

      expect(expense.amount_cents).to eq(amount_cents)
      expect(share.amount_owed_cents).to eq(amount_cents)
      expect(payment.amount_cents).to eq(amount_cents)
      expect(payment.source_financial_state_version).to eq(0)
    end
  end

  it "aceita todos os papéis e estados de Membership e preserva o escopo da unicidade", :aggregate_failures do
    %w[owner member].product(%w[active inactive]).each do |role, status|
      membership = insert_and_fetch(
        Membership,
        group_id: create(:group).id,
        user_id: create(:user).id,
        role:,
        status:
      )

      expect([ membership.role, membership.status ]).to eq([ role, status ])
    end

    shared_group = create(:group)
    shared_user = create(:user)
    other_group = create(:group)
    other_user = create(:user)

    first = insert_and_fetch(Membership, group_id: shared_group.id, user_id: shared_user.id, role: "member", status: "active")
    same_user_other_group = insert_and_fetch(Membership, group_id: other_group.id, user_id: shared_user.id, role: "member", status: "active")
    same_group_other_user = insert_and_fetch(Membership, group_id: shared_group.id, user_id: other_user.id, role: "member", status: "active")

    expect([ first.id, same_user_other_group.id, same_group_other_user.id ].uniq.size).to eq(3)
  end

  it "aceita auditoria de Expense ausente ou completa, replacement e escopos de share", :aggregate_failures do
    group = create(:group)
    creator = create(:user)
    voider = create(:user)
    other_user = create(:user)
    base_attributes = expense_attributes(group:, user: creator)

    active = insert_and_fetch(Expense, **base_attributes.merge(description: "Ativa"))
    voided = insert_and_fetch(
      Expense,
      **base_attributes.merge(
        description: "Anulada",
        voided_at: Time.current,
        voided_by_user_id: voider.id,
        void_reason: "Correção"
      )
    )
    replacement = insert_and_fetch(
      Expense,
      **base_attributes.merge(description: "Substituta", replaces_expense_id: active.id)
    )

    expect([ active.voided_at, active.voided_by_user_id, active.void_reason ]).to eq([ nil, nil, nil ])
    expect([ voided.voided_at, voided.voided_by_user_id, voided.void_reason ]).not_to include(nil)
    expect(replacement.replaces_expense_id).to eq(active.id)

    first = insert_and_fetch(ExpenseShare, expense_id: active.id, user_id: creator.id, amount_owed_cents: 1, position: 0)
    same_user_other_expense = insert_and_fetch(ExpenseShare, expense_id: voided.id, user_id: creator.id, amount_owed_cents: 1, position: 0)
    same_expense_other_user = insert_and_fetch(ExpenseShare, expense_id: active.id, user_id: other_user.id, amount_owed_cents: 1, position: 1)

    expect([ first.id, same_user_other_expense.id, same_expense_other_user.id ].uniq.size).to eq(3)
  end

  it "aceita todos os estados de Payment e chaves globais distintas", :aggregate_failures do
    group = create(:group)
    other_group = create(:group)
    from_user = create(:user)
    to_user = create(:user)
    base_attributes = payment_attributes(group:, from_user:, to_user:)

    reported = insert_and_fetch(Payment, **base_attributes)
    confirmed = insert_and_fetch(Payment, **confirmed_payment_attributes(base_attributes.merge(idempotency_key: database_uuid), to_user.id))
    cancelled = insert_and_fetch(Payment, **cancelled_payment_attributes(base_attributes.merge(idempotency_key: database_uuid), from_user.id))

    first_global = insert_and_fetch(Payment, **payment_attributes(group:, from_user:, to_user:, idempotency_key: database_uuid))
    other_global = insert_and_fetch(Payment, **payment_attributes(group: other_group, from_user:, to_user:, idempotency_key: database_uuid))

    expect([ reported.status, confirmed.status, cancelled.status ]).to eq(%w[reported confirmed cancelled])
    expect([ first_global.idempotency_key, other_global.idempotency_key ].uniq.size).to eq(2)
  end

  it "recusa NULL em cada FK ou campo de domínio obrigatório com NotNullViolation", :aggregate_failures do
    group = create(:group)
    user = create(:user)
    other_user = create(:user)
    expense = create(:expense, group:, paid_by_user: user, created_by_user: user)

    required_attribute_cases(group:, user:, other_user:, expense:).each do |model, column_name, attributes|
      expect_postgres_error(PG::NotNullViolation) do
        insert_direct(model, **attributes.merge(column_name => nil))
      end
    end
  end

  it "recusa UUID inexistente em cada FK com ForeignKeyViolation", :aggregate_failures do
    group = create(:group)
    user = create(:user)
    expense = create(:expense, group:, paid_by_user: user, created_by_user: user)
    from_user = create(:user)
    to_user = create(:user)

    foreign_key_cases(group:, user:, expense:, from_user:, to_user:).each do |model, attributes|
      expect_postgres_error(PG::ForeignKeyViolation) { insert_direct(model, **attributes) }
    end
  end

  it "recusa zero, negativo e overflow em cada coluna monetária com causa exata", :aggregate_failures do
    group = create(:group)
    from_user = create(:user)
    to_user = create(:user)
    expense = create(:expense, group:, paid_by_user: from_user, created_by_user: from_user)
    base_attributes = {
      Expense => expense_attributes(group:, user: from_user),
      ExpenseShare => { expense_id: expense.id, user_id: to_user.id, amount_owed_cents: 1, position: 0 },
      Payment => payment_attributes(group:, from_user:, to_user:)
    }

    MONEY_COLUMNS.each do |model, column_name|
      [ 0, -1 ].each do |invalid_amount|
        expect_postgres_error(PG::CheckViolation) do
          insert_direct(model, **base_attributes.fetch(model).merge(column_name => invalid_amount))
        end
      end

      expect_postgres_error(PG::NumericValueOutOfRange) do
        insert_direct(
          model,
          **base_attributes.fetch(model).merge(column_name => BIGINT_MAX + 1),
          raw_sql_values: { column_name => (BIGINT_MAX + 1).to_s }
        )
      end
    end
  end

  it "recusa enums, versões, self replacement e duplicidades estruturais", :aggregate_failures do
    group = create(:group)
    other_group = create(:group)
    user = create(:user)
    other_user = create(:user)
    expense = create(:expense, group:, paid_by_user: user, created_by_user: user)
    from_user = create(:user)
    to_user = create(:user)

    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Group, name: "Versão negativa", currency_code: "BRL", financial_state_version: -1)
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Membership, group_id: group.id, user_id: user.id, role: "admin", status: "active")
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Membership, group_id: group.id, user_id: user.id, role: "member", status: "pending")
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **payment_attributes(group:, from_user:, to_user:).merge(status: "processing"))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **payment_attributes(group:, from_user:, to_user:).merge(source_financial_state_version: -1))
    end
    expect_postgres_error(PG::CheckViolation) do
      insert_direct(Payment, **payment_attributes(group:, from_user:, to_user:).merge(to_user_id: from_user.id))
    end
    expect_postgres_error(PG::CheckViolation) do
      id = database_uuid
      insert_direct(Expense, **expense_attributes(group:, user:).merge(id:, replaces_expense_id: id))
    end

    insert_direct(Membership, group_id: group.id, user_id: user.id, role: "member", status: "active")
    expect_postgres_error(PG::UniqueViolation) do
      insert_direct(Membership, group_id: group.id, user_id: user.id, role: "owner", status: "inactive")
    end

    insert_direct(ExpenseShare, expense_id: expense.id, user_id: other_user.id, amount_owed_cents: 1, position: 0)
    expect_postgres_error(PG::UniqueViolation) do
      insert_direct(ExpenseShare, expense_id: expense.id, user_id: other_user.id, amount_owed_cents: 2, position: 1)
    end

    idempotency_key = database_uuid
    insert_direct(Payment, **payment_attributes(group:, from_user:, to_user:, idempotency_key:))
    expect_postgres_error(PG::UniqueViolation) do
      insert_direct(
        Payment,
        **payment_attributes(group: other_group, from_user:, to_user:, idempotency_key:).merge(
          request_fingerprint: "payload-diferente"
        )
      )
    end
  end

  it "recusa as seis combinações parciais da auditoria de Expense", :aggregate_failures do
    group = create(:group)
    user = create(:user)
    attributes = expense_attributes(group:, user:)

    partial_expense_audit_cases(user.id).each do |partial_metadata|
      expect_postgres_error(PG::CheckViolation) do
        insert_direct(Expense, **attributes.merge(partial_metadata))
      end
    end
  end

  it "recusa a matriz completa de metadados inválidos em cada estado de Payment", :aggregate_failures do
    group = create(:group)
    from_user = create(:user)
    to_user = create(:user)
    attributes = payment_attributes(group:, from_user:, to_user:)

    invalid_payment_audit_cases(attributes, from_user.id, to_user.id).each do |case_name, invalid_attributes|
      aggregate_failures(case_name) do
        expect_postgres_error(PG::CheckViolation) do
          insert_direct(Payment, **invalid_attributes)
        end
      end
    end
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def primary_key_columns(table_name)
    connection.select_values(<<~SQL.squish)
      SELECT attributes.attname
      FROM pg_constraint constraints
      JOIN pg_class tables ON tables.oid = constraints.conrelid
      JOIN unnest(constraints.conkey) WITH ORDINALITY AS keys(attnum, position) ON true
      JOIN pg_attribute attributes
        ON attributes.attrelid = constraints.conrelid AND attributes.attnum = keys.attnum
      WHERE constraints.contype = 'p'
        AND tables.oid = #{connection.quote(table_name)}::regclass
      ORDER BY keys.position
    SQL
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
    connection.columns(table_name).to_h do |column|
      [ column.name, [ column.sql_type, column.null ] ]
    end
  end

  def foreign_keys(table_name)
    connection.foreign_keys(table_name).map do |foreign_key|
      [ foreign_key.column, foreign_key.to_table, foreign_key.primary_key ]
    end.sort
  end

  def uuid_version(id)
    connection.select_value("SELECT uuid_extract_version(#{connection.quote(id)}::uuid)")
  end

  def database_uuid
    connection.select_value("SELECT uuidv7()")
  end

  def insert_direct(model, raw_sql_values: {}, **attributes)
    persisted_attributes = attributes.merge(created_at: Time.current, updated_at: Time.current)
    columns = persisted_attributes.keys.map { |column| connection.quote_column_name(column) }.join(", ")
    values = persisted_attributes.map do |column, value|
      raw_sql_values.fetch(column) { connection.quote(value) }
    end.join(", ")

    connection.select_value(<<~SQL.squish)
      INSERT INTO #{connection.quote_table_name(model.table_name)} (#{columns})
      VALUES (#{values})
      RETURNING id
    SQL
  end

  def insert_and_fetch(model, **attributes)
    model.find(insert_direct(model, **attributes))
  end

  def expect_postgres_error(error_class, &block)
    expect do
      ApplicationRecord.transaction(requires_new: true) do
        block.call
        raise ActiveRecord::Rollback
      end
    end.to raise_error(ActiveRecord::StatementInvalid) do |error|
      expect(error.cause).to be_instance_of(error_class)
    end
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
    attributes.merge(
      status: "cancelled",
      cancelled_by_user_id:,
      cancelled_at: Time.current,
      cancellation_reason: "Pagamento não realizado"
    )
  end

  def required_attribute_cases(group:, user:, other_user:, expense:)
    membership = { group_id: group.id, user_id: user.id, role: "member", status: "active" }
    expense_data = expense_attributes(group:, user:)
    share = { expense_id: expense.id, user_id: user.id, amount_owed_cents: 100, position: 0 }
    payment = payment_attributes(group:, from_user: user, to_user: other_user)

    [
      [ User, :email, { email: "direto-#{database_uuid}@example.com", encrypted_password: "senha" } ],
      [ User, :encrypted_password, { email: "direto-#{database_uuid}@example.com", encrypted_password: "senha" } ],
      *%i[name currency_code financial_state_version].map do |column_name|
        [ Group, column_name, { name: "Casa", currency_code: "BRL", financial_state_version: 0 } ]
      end,
      *%i[group_id user_id role status].map { |column_name| [ Membership, column_name, membership ] },
      *%i[group_id paid_by_user_id created_by_user_id amount_cents description occurred_on].map do |column_name|
        [ Expense, column_name, expense_data ]
      end,
      *%i[expense_id user_id amount_owed_cents position].map { |column_name| [ ExpenseShare, column_name, share ] },
      *%i[
        group_id from_user_id to_user_id amount_cents status idempotency_key request_fingerprint
        source_financial_state_version reported_by_user_id reported_at
      ].map { |column_name| [ Payment, column_name, payment ] }
    ]
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

  def partial_expense_audit_cases(voided_by_user_id)
    metadata = {
      voided_at: Time.current,
      voided_by_user_id:,
      void_reason: "Correção"
    }

    (1...7).map do |mask|
      metadata.each_with_index.to_h do |(column_name, value), index|
        [ column_name, (mask & (1 << index)).positive? ? value : nil ]
      end
    end
  end

  def invalid_payment_audit_cases(attributes, cancelled_by_user_id, confirmed_by_user_id)
    confirmed = confirmed_payment_attributes(attributes, confirmed_by_user_id)
    cancelled = cancelled_payment_attributes(attributes, cancelled_by_user_id)

    [
      [ "reported com confirmed_by", attributes.merge(confirmed_by_user_id:) ],
      [ "reported com confirmed_at", attributes.merge(confirmed_at: Time.current) ],
      [ "reported com cancelled_by", attributes.merge(cancelled_by_user_id:) ],
      [ "reported com cancelled_at", attributes.merge(cancelled_at: Time.current) ],
      [ "reported com reason", attributes.merge(cancellation_reason: "Motivo") ],
      [ "confirmed sem confirmed_by", confirmed.merge(confirmed_by_user_id: nil) ],
      [ "confirmed sem confirmed_at", confirmed.merge(confirmed_at: nil) ],
      [ "confirmed com cancelled_by", confirmed.merge(cancelled_by_user_id:) ],
      [ "confirmed com cancelled_at", confirmed.merge(cancelled_at: Time.current) ],
      [ "confirmed com reason", confirmed.merge(cancellation_reason: "Motivo") ],
      [ "cancelled sem cancelled_by", cancelled.merge(cancelled_by_user_id: nil) ],
      [ "cancelled sem cancelled_at", cancelled.merge(cancelled_at: nil) ],
      [ "cancelled sem reason", cancelled.merge(cancellation_reason: nil) ],
      [ "cancelled com confirmed_by", cancelled.merge(confirmed_by_user_id:) ],
      [ "cancelled com confirmed_at", cancelled.merge(confirmed_at: Time.current) ]
    ]
  end

  def index_columns(table_name)
    connection.indexes(table_name).map(&:columns)
  end

  def unique_index_columns(table_name)
    connection.indexes(table_name).select(&:unique).map(&:columns)
  end
end

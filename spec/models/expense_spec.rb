require "rails_helper"

RSpec.describe Expense do
  it "expõe a matriz exaustiva de associações e optionality" do
    contracts = described_class.reflect_on_all_associations.to_h do |reflection|
      optional = reflection.macro == :belongs_to ? reflection.options.fetch(:optional, false) : nil

      [
        reflection.name,
        {
          class_name: reflection.class_name,
          foreign_key: reflection.foreign_key,
          macro: reflection.macro,
          optional: optional
        }
      ]
    end

    expect(contracts).to eq(
      group: { class_name: "Group", foreign_key: "group_id", macro: :belongs_to, optional: false },
      paid_by_user: { class_name: "User", foreign_key: "paid_by_user_id", macro: :belongs_to, optional: false },
      created_by_user: { class_name: "User", foreign_key: "created_by_user_id", macro: :belongs_to, optional: false },
      voided_by_user: { class_name: "User", foreign_key: "voided_by_user_id", macro: :belongs_to, optional: true },
      replaces_expense: { class_name: "Expense", foreign_key: "replaces_expense_id", macro: :belongs_to, optional: true },
      replacement_expenses: { class_name: "Expense", foreign_key: "replaces_expense_id", macro: :has_many, optional: nil },
      expense_shares: { class_name: "ExpenseShare", foreign_key: "expense_id", macro: :has_many, optional: nil }
    )
  end

  it "persiste creator e pagador distintos como fatos nomeados" do
    expense = create(:expense).reload

    expect(expense).to be_persisted
    expect(expense.paid_by_user).not_to eq(expense.created_by_user)
  end

  it "persiste creator e pagador quando são a mesma pessoa" do
    user = create(:user)
    expense = create(:expense, paid_by_user: user, created_by_user: user).reload

    expect(expense).to be_persisted
    expect(expense.paid_by_user).to eq(user)
    expect(expense.created_by_user).to eq(user)
  end

  it "persiste despesas ativas e anuladas" do
    active_expense = create(:expense).reload
    voided_expense = create(:expense, :voided).reload

    expect(active_expense).to be_persisted
    expect(active_expense.voided_at).to be_nil
    expect(active_expense.voided_by_user).to be_nil
    expect(active_expense.void_reason).to be_nil
    expect(voided_expense).to be_persisted
    expect(voided_expense.voided_at).to be_present
    expect(voided_expense.voided_by_user).to be_present
    expect(voided_expense.void_reason).to be_present
  end

  it "persiste a relação entre despesa original e substituta" do
    original_expense = create(:expense)
    replacement_expense = create(:expense, group: original_expense.group, replaces_expense: original_expense).reload

    expect(replacement_expense).to be_persisted
    expect(replacement_expense.replaces_expense).to eq(original_expense)
    expect(original_expense.reload.replacement_expenses).to contain_exactly(replacement_expense)
  end
end

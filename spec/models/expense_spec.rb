require "rails_helper"

RSpec.describe Expense do
  it "preserva creator e pagador como fatos nomeados, inclusive quando são a mesma pessoa" do
    expense = create(:expense)
    user = create(:user)
    same_actor_expense = create(:expense, paid_by_user: user, created_by_user: user)

    expect(expense.paid_by_user).to be_present
    expect(expense.created_by_user).to be_present
    expect(same_actor_expense.paid_by_user).to eq(user)
    expect(same_actor_expense.created_by_user).to eq(user)
    expect(Expense.reflect_on_association(:replacement_expenses).foreign_key).to eq("replaces_expense_id")
  end
end

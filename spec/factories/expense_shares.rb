FactoryBot.define do
  factory :expense_share do
    expense
    user
    amount_owed_cents { 100 }
    position { 0 }
  end
end

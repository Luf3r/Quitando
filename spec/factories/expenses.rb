FactoryBot.define do
  factory :expense do
    group
    paid_by_user { association :user }
    created_by_user { association :user }
    amount_cents { 100 }
    description { "Mercado" }
    occurred_on { Date.current }

    trait :voided do
      voided_by_user { association :user }
      voided_at { Time.current }
      void_reason { "Valor informado incorretamente" }
    end
  end
end

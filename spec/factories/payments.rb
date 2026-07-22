FactoryBot.define do
  factory :payment do
    group
    from_user { association :user }
    to_user { association :user }
    amount_cents { 100 }
    status { :reported }
    idempotency_key { SecureRandom.uuid }
    request_fingerprint { SecureRandom.hex(32) }
    source_financial_state_version { 0 }
    reported_by_user { from_user }
    reported_at { Time.current }

    trait :confirmed do
      status { :confirmed }
      confirmed_by_user { to_user }
      confirmed_at { Time.current }
    end

    trait :cancelled do
      status { :cancelled }
      cancelled_by_user { from_user }
      cancelled_at { Time.current }
      cancellation_reason { "Pagamento não realizado" }
    end
  end
end

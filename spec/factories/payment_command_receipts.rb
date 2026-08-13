FactoryBot.define do
  factory :payment_command_receipt do
    payment
    command_type { :report }
    idempotency_key { SecureRandom.uuid }
    request_fingerprint { Digest::SHA256.hexdigest(SecureRandom.hex) }

    trait :expense_correct do
      payment { nil }
      expense
      command_type { :expense_correct }
    end
  end
end

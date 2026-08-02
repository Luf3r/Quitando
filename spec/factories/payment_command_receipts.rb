FactoryBot.define do
  factory :payment_command_receipt do
    payment
    command_type { :report }
    idempotency_key { SecureRandom.uuid }
    request_fingerprint { Digest::SHA256.hexdigest(SecureRandom.hex) }
  end
end

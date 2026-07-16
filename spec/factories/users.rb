FactoryBot.define do
  factory :user do
    sequence(:email) { |index| "user#{index}@example.com" }
    password { "senha-segura" }
    password_confirmation { password }
  end
end

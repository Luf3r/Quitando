FactoryBot.define do
  factory :user do
    sequence(:name) { |index| "Pessoa #{index}" }
    sequence(:email) { |index| "user#{index}@example.com" }
    password { "senha-segura" }
    password_confirmation { password }

    trait :demo_account do
      demo_account { true }
    end
  end
end

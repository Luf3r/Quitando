FactoryBot.define do
  factory :group_invitation do
    group
    association :invited_user, factory: :user
    association :invited_by_user, factory: :user
    status { :pending }
    expires_at { 7.days.from_now }

    trait :accepted do
      status { :accepted }
      accepted_at { Time.current }
    end

    trait :declined do
      status { :declined }
      declined_at { Time.current }
    end

    trait :revoked do
      status { :revoked }
      revoked_at { Time.current }
    end

    trait :expired do
      status { :expired }
      expired_at { Time.current }
    end
  end
end

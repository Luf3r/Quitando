FactoryBot.define do
  factory :membership do
    group
    user
    role { :member }
    status { :active }
    sequence(:position)
  end
end

FactoryBot.define do
  factory :membership do
    group
    user
    role { :member }
    status { :active }
  end
end

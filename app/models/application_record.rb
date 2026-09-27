class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  if Rails.env.development? || Rails.env.test?
    connects_to shards: {
      default: { writing: :primary },
      demo: { writing: :demo }
    }
  end
end

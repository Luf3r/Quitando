RSpec.configure do |config|
  config.before(:suite) do
    next if SolidCable::Message.connection.table_exists?("solid_cable_messages")

    load Rails.root.join("db/cable_schema.rb")
  end
end

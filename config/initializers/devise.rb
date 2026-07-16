require "devise/orm/active_record"

Devise.setup do |config|
  config.mailer_sender = "no-reply@quitando.test"
end

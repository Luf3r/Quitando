class DemoScenario::Config
  class Error < StandardError; end
  class DemoModeDisabled < Error; end
  class PublicPasswordMissing < Error; end
  class UnauthorizedDatabase < Error; end
  class ManualConfirmationMissing < Error; end

  def initialize(environment: ENV)
    @environment = environment
  end

  def public_password
    @environment["QUITANDO_DEMO_PASSWORD"]
  end

  def validate_installation!
    validate_demo_mode!
    validate_public_password!
    validate_database!
    self
  end

  def validate_reset!
    validate_installation!
    validate_manual_confirmation!
    self
  end

  private

  def validate_demo_mode!
    return if @environment["QUITANDO_DEMO_MODE"] == "true"

    raise DemoModeDisabled, "QUITANDO_DEMO_MODE must be exactly true"
  end

  def validate_public_password!
    return if public_password&.strip&.length&.positive?

    raise PublicPasswordMissing, "QUITANDO_DEMO_PASSWORD must be present"
  end

  def validate_database!
    return if authorized_database_name == current_database_name

    raise UnauthorizedDatabase, "QUITANDO_DEMO_DATABASE_NAME must exactly match the current database"
  end

  def validate_manual_confirmation!
    return if @environment["CONFIRM_DEMO_RESET"] == "quitando-demo-only"

    raise ManualConfirmationMissing, "CONFIRM_DEMO_RESET must be exactly quitando-demo-only"
  end

  def authorized_database_name
    @environment["QUITANDO_DEMO_DATABASE_NAME"]
  end

  def current_database_name
    ActiveRecord::Base.connection_db_config.database
  end
end

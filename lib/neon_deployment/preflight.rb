require "uri"
require "pg"

module NeonDeployment
  class ConfigurationError < StandardError; end
  class ConnectionError < StandardError; end

  class Preflight
    SERVICES = {
      "DATABASE_URL" => "QUITANDO_DIRECT_DATABASE_URL",
      "CACHE_DATABASE_URL" => "QUITANDO_DIRECT_CACHE_DATABASE_URL",
      "QUEUE_DATABASE_URL" => "QUITANDO_DIRECT_QUEUE_DATABASE_URL",
      "CABLE_DATABASE_URL" => "QUITANDO_DIRECT_CABLE_DATABASE_URL"
    }.freeze
    EXPECTED_DATABASES = {
      "false" => %w[Quitando quitando_cache quitando_queue quitando_cable],
      "true" => %w[Demo demo_cache demo_queue demo_cable]
    }.freeze
    AUXILIARY_DATABASE_NAME_VARIABLES = {
      "CACHE_DATABASE_URL" => "QUITANDO_CACHE_DATABASE_NAME",
      "QUEUE_DATABASE_URL" => "QUITANDO_QUEUE_DATABASE_NAME",
      "CABLE_DATABASE_URL" => "QUITANDO_CABLE_DATABASE_NAME"
    }.freeze
    ALLOWED_QUERY = { "sslmode" => "require", "channel_binding" => "require" }.freeze

    def initialize(environment: ENV, connection_factory: ->(url) { PG.connect(url, connect_timeout: 5) })
      @environment = environment
      @connection_factory = connection_factory
    end

    def call!
      configs = validate_configuration!
      configs.each do |_runtime_variable, config|
        verify_database!(config.fetch(:variable), config.fetch(:uri), config.fetch(:database))
        verify_database!(config.fetch(:runtime_variable), config.fetch(:runtime_uri), config.fetch(:database))
      end
      true
    end

    private

    def validate_configuration!
      demo_mode = @environment.fetch("QUITANDO_DEMO_MODE", nil)
      unless %w[true false].include?(demo_mode)
        raise ConfigurationError, "QUITANDO_DEMO_MODE must be explicitly true or false"
      end

      primary_name_variable = demo_mode == "true" ? "QUITANDO_DEMO_DATABASE_NAME" : "QUITANDO_MAIN_DATABASE_NAME"
      expected_primary_name = required_value!(primary_name_variable)
      other_name_variable = demo_mode == "true" ? "QUITANDO_MAIN_DATABASE_NAME" : "QUITANDO_DEMO_DATABASE_NAME"
      if @environment[other_name_variable] && !@environment[other_name_variable].empty?
        raise ConfigurationError, "#{other_name_variable} must not be set for this app"
      end

      configs = SERVICES.map do |runtime_variable, direct_variable|
        runtime_url = required_value!(runtime_variable)
        direct_url = required_value!(direct_variable)
        runtime = parse_url!(runtime_variable, runtime_url, pooled: true)
        direct = parse_url!(runtime_variable, direct_url, pooled: false)
        validate_pair!(runtime_variable, runtime, direct)
        [ runtime_variable, direct.merge(
          variable: direct_variable,
          runtime_uri: runtime.fetch(:uri),
          runtime_variable:
        ) ]
      end

      names = configs.map { |_variable, config| config.fetch(:database) }
      unless names.uniq.length == names.length
        raise ConfigurationError, "The four Neon databases must have distinct names"
      end
      expected_databases = EXPECTED_DATABASES.fetch(demo_mode)
      names.each_with_index do |name, index|
        runtime_variable = SERVICES.keys[index]
        name_variable = index.zero? ? primary_name_variable : AUXILIARY_DATABASE_NAME_VARIABLES.fetch(runtime_variable)
        configured_name = index.zero? ? expected_primary_name : required_value!(name_variable)
        next if name == expected_databases[index] && configured_name == expected_databases[index]

        raise ConfigurationError, "#{name_variable} must match #{runtime_variable} for this Neon app"
      end
      endpoints = configs.map { |_variable, config| endpoint_for(config.fetch(:host)) }.uniq
      unless endpoints.length == 1
        raise ConfigurationError, "The four databases must belong to the same Neon project"
      end
      unless configs.first.last.fetch(:database) == expected_primary_name
        raise ConfigurationError, "#{primary_name_variable} must match the primary database URL"
      end

      configs
    end

    def required_value!(variable)
      value = @environment[variable]
      if value.nil? || value.empty?
        raise ConfigurationError, "#{variable} is required for Neon connection verification"
      end
      value
    end

    def parse_url!(variable, value, pooled:)
      uri = URI.parse(value)
      valid_scheme = %w[postgres postgresql].include?(uri.scheme)
      valid_host = uri.host && uri.host.start_with?("ep-") && uri.host.end_with?(".neon.tech")
      database = uri.path.delete_prefix("/")
      query_pairs = URI.decode_www_form(uri.query.to_s)
      query = query_pairs.to_h
      pooler_host = uri.host&.match?(/-pooler\./)

      valid_port = uri.port.nil? || uri.port == 5432
      unless valid_scheme && valid_host && uri.user && !uri.password.to_s.empty? && valid_port && uri.fragment.nil? && database.match?(/\A[A-Za-z0-9_-]+\z/) && query_pairs.length == ALLOWED_QUERY.length && query == ALLOWED_QUERY && pooler_host == pooled
        raise ConfigurationError, "#{variable} must be a valid #{pooled ? 'pooled' : 'direct'} Neon PostgreSQL URL with sslmode=require and channel_binding=require"
      end

      { uri:, database:, host: uri.host, username: uri.user, password: uri.password }
    rescue URI::InvalidURIError, ArgumentError
      raise ConfigurationError, "#{variable} is not a valid Neon PostgreSQL URL"
    end

    def validate_pair!(variable, runtime, direct)
      same_endpoint = endpoint_for(runtime.fetch(:host)) == direct.fetch(:host)
      same_credentials = runtime.fetch(:username) == direct.fetch(:username) && runtime.fetch(:password) == direct.fetch(:password)
      same_database = runtime.fetch(:database) == direct.fetch(:database)
      unless same_endpoint && same_credentials && same_database
        raise ConfigurationError, "#{variable} and its direct migration URL must target the same Neon database and endpoint"
      end
    end

    def endpoint_for(host)
      host.sub("-pooler.", ".")
    end

    def verify_database!(variable, uri, database)
      connection = nil
      begin
        connection = @connection_factory.call(uri.to_s)
        connection.exec("SET statement_timeout = '5000ms'")
        connection.exec("BEGIN READ ONLY")
        result = connection.exec("SELECT current_database() AS database_name, current_setting('server_version_num')::integer AS server_version_num")
        row = result.first

        unless row && row.fetch("database_name") == database
          raise ConnectionError, "#{variable} connected to an unexpected database"
        end

        server_version_num = Integer(row.fetch("server_version_num"), 10)
        unless server_version_num / 10_000 == 18
          raise ConnectionError, "#{variable} must connect to PostgreSQL 18"
        end
        connection.exec("COMMIT")
      rescue PG::Error => error
        raise ConnectionError, "Unable to verify #{variable} (#{error.class})"
      ensure
        connection&.close
      end
    end
  end
end

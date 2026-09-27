class LocalEnvironment
  REAL_HOSTS = %w[localhost].freeze
  DEMO_HOST = "demo.localhost"

  class << self
    def dual_database?
      (Rails.env.development? || Rails.env.test?) && ENV["QUITANDO_LOCAL_DUAL_DATABASE"] == "true"
    end

    def shard_for_host(host)
      return :default if REAL_HOSTS.include?(host)
      return :default if Rails.env.test? && %w[www.example.com 127.0.0.1].include?(host)
      return :demo if host == DEMO_HOST

      nil
    end

    def demo?
      ENV["QUITANDO_DEMO_MODE"] == "true" || (dual_database? && ApplicationRecord.current_shard == :demo)
    end

    def stream_name(group_id)
      "#{ApplicationRecord.current_shard}:#{group_id}"
    end
  end
end

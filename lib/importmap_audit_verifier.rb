require "open3"

class ImportmapAuditVerifier
  TRANSIENT_NPM_TRANSPORT_ERROR = /Importmap::Npm::HTTPError|Net::(?:Open|Read|Write)Timeout|SocketError/.freeze

  def initialize(
    command: [ File.expand_path("../bin/importmap", __dir__), "audit" ],
    max_attempts: Integer(ENV.fetch("IMPORTMAP_AUDIT_MAX_ATTEMPTS", "3"), 10),
    retry_delay_seconds: Float(ENV.fetch("IMPORTMAP_AUDIT_RETRY_DELAY_SECONDS", "2")),
    runner: ->(command) { Open3.capture3(*command) },
    sleeper: ->(seconds) { sleep(seconds) },
    output: $stdout,
    error: $stderr
  )
    raise ArgumentError, "max_attempts must be positive" unless max_attempts.positive?
    raise ArgumentError, "retry_delay_seconds must be non-negative" if retry_delay_seconds.negative?

    @command = command
    @max_attempts = max_attempts
    @retry_delay_seconds = retry_delay_seconds
    @runner = runner
    @sleeper = sleeper
    @output = output
    @error = error
  end

  def call
    1.upto(@max_attempts) do |attempt|
      stdout, stderr, status = @runner.call(@command)
      @output.print(stdout)
      @error.print(stderr)
      return true if status.success?

      if retryable_transport_error?(stderr) && attempt < @max_attempts
        @error.puts(
          "Importmap audit transient npm transport error on attempt #{attempt}/#{@max_attempts}; " \
          "retrying in #{@retry_delay_seconds} seconds."
        )
        @sleeper.call(@retry_delay_seconds)
        next
      end

      failure_kind = retryable_transport_error?(stderr) ? "transient npm transport error" : "non-retryable failure"
      @error.puts("Importmap audit failed after #{attempt} attempts (#{failure_kind}).")
      return false
    end
  end

  private

  def retryable_transport_error?(stderr)
    stderr.match?(TRANSIENT_NPM_TRANSPORT_ERROR)
  end
end

require "timeout"

class FinancialMigrationCommandRunner
  class CommandTimedOut < StandardError; end
  class TerminationUnconfirmed < CommandTimedOut; end

  def initialize(timeout_seconds:, termination_grace_seconds:)
    @timeout_seconds = timeout_seconds
    @termination_grace_seconds = termination_grace_seconds
  end

  def call(*command, environment:)
    pid = Process.spawn(environment, *command, pgroup: true)
    wait_for_process(pid, timeout_seconds)
  rescue Timeout::Error
    if !pid || terminate_process_group(pid)
      raise CommandTimedOut, "command timed out after #{timeout_seconds}s", cause: nil
    end

    raise TerminationUnconfirmed,
      "command timed out after #{timeout_seconds}s; process termination was not confirmed",
      cause: nil
  end

  private

  attr_reader :timeout_seconds, :termination_grace_seconds

  def wait_for_process(pid, timeout)
    Timeout.timeout(timeout) { Process.wait2(pid).last }
  end

  def terminate_process_group(pid)
    Process.kill("TERM", -pid)
    wait_for_process(pid, termination_grace_seconds)
    true
  rescue Timeout::Error
    wait_for_forced_termination(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    true
  end

  def wait_for_forced_termination(pid)
    Process.kill("KILL", -pid)
    wait_for_process(pid, termination_grace_seconds)
    true
  rescue Timeout::Error, Errno::ESRCH, Errno::ECHILD
    false
  end
end

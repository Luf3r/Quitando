require "timeout"

class FinancialMigrationCommandRunner
  class CommandTimedOut < StandardError; end
  class TerminationUnconfirmed < CommandTimedOut; end

  PROCESS_GROUP_POLL_INTERVAL_SECONDS = 0.01

  def initialize(timeout_seconds:, termination_grace_seconds:)
    @timeout_seconds = timeout_seconds
    @termination_grace_seconds = termination_grace_seconds
  end

  def call(*command, environment:, **spawn_options)
    pid = Process.spawn(environment, *command, pgroup: true, **spawn_options)
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
    return true if wait_for_process_group_disappearance(pid, termination_grace_seconds)

    force_process_group_termination(pid)
  rescue Timeout::Error, Errno::ECHILD
    force_process_group_termination(pid)
  rescue Errno::ESRCH
    true
  rescue Errno::EPERM
    false
  end

  def force_process_group_termination(pid)
    Process.kill("KILL", -pid)
    wait_for_process_group_disappearance(pid, termination_grace_seconds)
  rescue Errno::ESRCH
    true
  rescue Errno::EPERM
    false
  end

  def wait_for_process_group_disappearance(pid, timeout)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

    loop do
      return true if process_group_disappeared?(pid)

      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return false if remaining <= 0

      sleep [ PROCESS_GROUP_POLL_INTERVAL_SECONDS, remaining ].min
    end
  end

  def process_group_disappeared?(pid)
    Process.kill(0, -pid)
    false
  rescue Errno::ESRCH
    true
  rescue Errno::EPERM
    false
  end
end

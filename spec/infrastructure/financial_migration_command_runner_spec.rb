require "rails_helper"
require "rbconfig"
require "tmpdir"
require Rails.root.join("lib/financial_migration_command_runner")

RSpec.describe FinancialMigrationCommandRunner do
  it "limits the final wait after KILL and preserves the original timeout" do
    pid = 4_242
    runner = described_class.new(timeout_seconds: 0.02, termination_grace_seconds: 0.02)
    allow(Process).to receive(:spawn).and_return(pid)
    allow(Process).to receive(:wait2) { sleep 1 }
    expect(Process).to receive(:kill).with("TERM", -pid).ordered
    expect(Process).to receive(:kill).with("KILL", -pid).ordered

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    expect do
      runner.call("uninterruptible-command", environment: {})
    end.to raise_error(described_class::CommandTimedOut, "command timed out after 0.02s")

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    expect(elapsed).to be < 0.25
  end

  it "termina o grupo de processo real e não deixa o filho vivo após timeout" do
    Dir.mktmpdir("financial-command-timeout") do |directory|
      child_pid_path = File.join(directory, "child.pid")
      command_path = File.join(directory, "blocking_command.rb")
      File.write(
        command_path,
        <<~'RUBY'
          child_pid_path = ARGV.fetch(0)
          child_pid = fork { sleep 60 }
          trap("TERM") do
            Process.wait(child_pid)
            exit 0
          rescue Errno::ECHILD
            exit 0
          end
          File.write(child_pid_path, child_pid)
          sleep 60
        RUBY
      )
      runner = described_class.new(timeout_seconds: 0.2, termination_grace_seconds: 2)

      expect do
        runner.call(RbConfig.ruby, command_path, child_pid_path, environment: {})
      end.to raise_error(described_class::CommandTimedOut)

      child_pid = Integer(File.read(child_pid_path), 10)
      expect { Process.kill(0, child_pid) }.to raise_error(Errno::ESRCH)
    end
  end
end

require "rails_helper"
require "rbconfig"
require "tmpdir"
require Rails.root.join("lib/financial_migration_command_runner")

RSpec.describe FinancialMigrationCommandRunner do
  it "surfaces an unconfirmed termination after bounded TERM and KILL waits" do
    pid = 4_242
    runner = described_class.new(timeout_seconds: 0.02, termination_grace_seconds: 0.02)
    allow(Process).to receive(:spawn).and_return(pid)
    allow(Process).to receive(:wait2) { sleep 1 }
    allow(Process).to receive(:kill).with(0, -pid).and_return(1)
    expect(Process).to receive(:kill).with("TERM", -pid).ordered
    expect(Process).to receive(:kill).with("KILL", -pid).ordered

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    expect do
      runner.call("uninterruptible-command", environment: {})
    end.to raise_error(
      described_class::TerminationUnconfirmed,
      "command timed out after 0.02s; process termination was not confirmed"
    )

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    expect(elapsed).to be < 0.25
  end

  it "kills an uncooperative descendant before confirming process-group release" do
    Dir.mktmpdir("financial-command-uncooperative-descendant") do |directory|
      child_pid = nil
      begin
        child_pid_path = File.join(directory, "child.pid")
        heartbeat_path = File.join(directory, "child.heartbeat")
        command_path = File.join(directory, "uncooperative_command.rb")
        File.write(
          command_path,
          <<~'RUBY'
            child_pid_path = ARGV.fetch(0)
            heartbeat_path = ARGV.fetch(1)
            child_pid = fork do
              trap("TERM") { }
              loop do
                File.write(heartbeat_path, Process.clock_gettime(Process::CLOCK_MONOTONIC).to_s)
                sleep 0.01
              end
            end
            File.write(child_pid_path, child_pid)
            trap("TERM") { exit! 0 }
            sleep 60
          RUBY
        )
        runner = described_class.new(timeout_seconds: 0.2, termination_grace_seconds: 0.2)

        expect do
          runner.call(RbConfig.ruby, command_path, child_pid_path, heartbeat_path, environment: {})
        end.to raise_error(described_class::CommandTimedOut)

        child_pid = Integer(File.read(child_pid_path), 10)
        heartbeat = File.read(heartbeat_path)
        sleep 0.1
        expect(File.read(heartbeat_path)).to eq(heartbeat)
      ensure
        begin
          Process.kill("KILL", child_pid) if child_pid
        rescue Errno::ESRCH
          nil
        end
      end
    end
  end

  it "waits for process-group disappearance after the leader exits before confirming release" do
    pid = 4_243
    runner = described_class.new(timeout_seconds: 0.02, termination_grace_seconds: 0.02)
    wait_calls = 0
    group_checks = 0
    signals = []
    allow(Process).to receive(:spawn).and_return(pid)
    allow(Process).to receive(:wait2) do
      wait_calls += 1
      sleep 1 if wait_calls == 1

      [ pid, nil ]
    end
    allow(Process).to receive(:kill).with(0, -pid) do
      group_checks += 1
      raise Errno::ESRCH if signals.include?("KILL")

      1
    end
    allow(Process).to receive(:kill).with("TERM", -pid) { signals << "TERM" }
    allow(Process).to receive(:kill).with("KILL", -pid) { signals << "KILL" }

    expect do
      runner.call("leader-exits-before-descendant", environment: {})
    end.to raise_error(described_class::CommandTimedOut, "command timed out after 0.02s")

    expect(signals).to eq(%w[TERM KILL])
    expect(group_checks).to be >= 2
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

require "rails_helper"
require "rbconfig"
require "tmpdir"
require Rails.root.join("lib/financial_migration_command_runner")

RSpec.describe FinancialMigrationCommandRunner do
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

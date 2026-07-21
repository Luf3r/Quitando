require "open3"
require "tmpdir"

RSpec.describe "Production image verifier safety" do
  PRODUCTION_IMAGE_SCRIPT_PATH = File.expand_path("../../bin/verify-production-image", __dir__)

  def run_verifier(fake_docker_directory, log_path, environment = {})
    Open3.capture3(
      {
        "DOCKER_FAKE_LOG" => log_path,
        "PATH" => "#{fake_docker_directory}:#{ENV.fetch('PATH')}"
      }.merge(environment),
      PRODUCTION_IMAGE_SCRIPT_PATH
    )
  end

  def with_fake_docker
    Dir.mktmpdir("production-image-docker-fake") do |directory|
      log_path = File.join(directory, "docker.log")
      docker_path = File.join(directory, "docker")
      File.write(
        docker_path,
        <<~BASH
          #!/usr/bin/env bash
          set -u

          printf '%s\n' "$*" >> "${DOCKER_FAKE_LOG}"

          if [[ "$1 $2" == "image inspect" ]]; then
            exit "${DOCKER_FAKE_INSPECT_STATUS:-1}"
          fi

          if [[ "$1" == "run" ]]; then
            exit "${DOCKER_FAKE_RUN_STATUS:-0}"
          fi

          exit 0
        BASH
      )
      File.chmod(0o755, docker_path)

      yield directory, log_path
    end
  end

  it "removes the exact newly built tag and preserves a failed inspection status", :aggregate_failures do
    with_fake_docker do |directory, log_path|
      _stdout, _stderr, status = run_verifier(
        directory,
        log_path,
        "DOCKER_FAKE_RUN_STATUS" => "23"
      )
      commands = File.readlines(log_path, chomp: true)
      build_command = commands.find { |command| command.start_with?("build ") }
      image_tag = build_command.match(/--tag (\S+)/)[1]

      expect(status.exitstatus).to eq(23)
      expect(commands.grep(/^run /)).to contain_exactly(a_string_including(image_tag))
      expect(commands.grep(/^image rm /)).to eq([ "image rm #{image_tag}" ])
    end
  end

  it "refuses a preexisting tag without building or removing it", :aggregate_failures do
    with_fake_docker do |directory, log_path|
      _stdout, stderr, status = run_verifier(
        directory,
        log_path,
        "DOCKER_FAKE_INSPECT_STATUS" => "0"
      )
      commands = File.readlines(log_path, chomp: true)

      expect(status).not_to be_success
      expect(stderr).to include("already exists")
      expect(commands.grep(/^build /)).to be_empty
      expect(commands.grep(/^image rm /)).to be_empty
    end
  end
end

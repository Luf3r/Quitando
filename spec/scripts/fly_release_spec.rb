require "rails_helper"
require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe "Fly release migrations" do
  let(:release_script) { Rails.root.join("bin/fly-release") }

  it "usa conexões diretas e instala o cenário apenas no app demo" do
    Dir.mktmpdir do |directory|
      capture_path = File.join(directory, "calls.txt")
      prepare_fake_rails(directory)
      output, status = Open3.capture2e(release_environment(capture_path), "bash", release_script.to_s, chdir: directory)

      expect(status).to be_success, output
      calls = File.readlines(capture_path, chomp: true)
      expect(calls).to eq([
        "postgres://direct-main|postgres://direct-cache|postgres://direct-queue|postgres://direct-cable|db:prepare",
        "postgres://direct-main|postgres://direct-cache|postgres://direct-queue|postgres://direct-cable|db:seed"
      ])
    end
  end

  it "falha antes de executar migrations quando uma conexão direta está ausente" do
    Dir.mktmpdir do |directory|
      capture_path = File.join(directory, "calls.txt")
      prepare_fake_rails(directory)
      environment = release_environment(capture_path).merge("QUITANDO_DIRECT_QUEUE_DATABASE_URL" => "")
      output, status = Open3.capture2e(environment, "bash", release_script.to_s, chdir: directory)

      expect(status).not_to be_success
      expect(output).to include("QUITANDO_DIRECT_QUEUE_DATABASE_URL is required")
      expect(File).not_to exist(capture_path)
    end
  end

  private

  def release_environment(capture_path)
    {
      "CAPTURE_PATH" => capture_path,
      "QUITANDO_DEMO_MODE" => "true",
      "QUITANDO_DIRECT_DATABASE_URL" => "postgres://direct-main",
      "QUITANDO_DIRECT_CACHE_DATABASE_URL" => "postgres://direct-cache",
      "QUITANDO_DIRECT_QUEUE_DATABASE_URL" => "postgres://direct-queue",
      "QUITANDO_DIRECT_CABLE_DATABASE_URL" => "postgres://direct-cable",
      "DATABASE_URL" => "postgres://pooled-main",
      "CACHE_DATABASE_URL" => "postgres://pooled-cache",
      "QUEUE_DATABASE_URL" => "postgres://pooled-queue",
      "CABLE_DATABASE_URL" => "postgres://pooled-cable"
    }
  end

  def prepare_fake_rails(directory)
    bin_directory = File.join(directory, "bin")
    FileUtils.mkdir_p(bin_directory)
    File.write(
      File.join(bin_directory, "rails"),
      "#!/bin/sh\nprintf '%s|%s|%s|%s|%s\\n' \"$DATABASE_URL\" \"$CACHE_DATABASE_URL\" \"$QUEUE_DATABASE_URL\" \"$CABLE_DATABASE_URL\" \"$*\" >> \"$CAPTURE_PATH\"\n"
    )
    FileUtils.chmod(0o755, File.join(bin_directory, "rails"))
  end
end

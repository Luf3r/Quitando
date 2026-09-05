require "rails_helper"
require "stringio"
require Rails.root.join("lib/importmap_audit_verifier")

RSpec.describe ImportmapAuditVerifier do
  Status = Struct.new(:success?)

  it "succeeds when the real audit command succeeds on the first attempt" do
    output = StringIO.new
    errors = StringIO.new
    runner = instance_double("AuditRunner")
    allow(runner).to receive(:call).with([ "bin/importmap", "audit" ]).and_return([ "No vulnerabilities found.\n", "", Status.new(true) ])

    result = described_class.new(command: [ "bin/importmap", "audit" ], runner: runner, output: output, error: errors).call

    expect(result).to be(true)
    expect(runner).to have_received(:call).once
    expect(output.string).to include("No vulnerabilities found.")
    expect(errors.string).to be_empty
  end

  it "retries a transient npm transport error and succeeds only after a real successful attempt" do
    output = StringIO.new
    errors = StringIO.new
    sleeper = instance_double("Sleeper")
    allow(sleeper).to receive(:call)
    runner = instance_double("AuditRunner")
    allow(runner).to receive(:call).with([ "bin/importmap", "audit" ]).and_return(
      [ "", "Importmap::Npm::HTTPError: Unexpected transport error\nNet::ReadTimeout\n", Status.new(false) ],
      [ "No vulnerabilities found.\n", "", Status.new(true) ]
    )

    result = described_class.new(
      command: [ "bin/importmap", "audit" ],
      runner: runner,
      sleeper: sleeper,
      retry_delay_seconds: 0.25,
      output: output,
      error: errors
    ).call

    expect(result).to be(true)
    expect(runner).to have_received(:call).twice
    expect(sleeper).to have_received(:call).with(0.25).once
    expect(errors.string).to include("transient npm transport error on attempt 1/3")
  end

  it "fails explicitly after bounded retries instead of accepting a transport failure as success" do
    output = StringIO.new
    errors = StringIO.new
    sleeper = instance_double("Sleeper")
    allow(sleeper).to receive(:call)
    runner = instance_double("AuditRunner")
    allow(runner).to receive(:call).with([ "bin/importmap", "audit" ]).and_return(
      [ "", "Importmap::Npm::HTTPError: Unexpected transport error\nNet::ReadTimeout\n", Status.new(false) ]
    )

    result = described_class.new(
      command: [ "bin/importmap", "audit" ],
      max_attempts: 2,
      runner: runner,
      sleeper: sleeper,
      output: output,
      error: errors
    ).call

    expect(result).to be(false)
    expect(runner).to have_received(:call).twice
    expect(sleeper).to have_received(:call).once
    expect(errors.string).to include("failed after 2 attempts")
  end

  it "does not retry a completed audit that reports a vulnerability" do
    errors = StringIO.new
    runner = instance_double("AuditRunner")
    allow(runner).to receive(:call).with([ "bin/importmap", "audit" ]).and_return(
      [ "", "Vulnerabilities found.\n", Status.new(false) ]
    )

    result = described_class.new(command: [ "bin/importmap", "audit" ], runner: runner, output: StringIO.new, error: errors).call

    expect(result).to be(false)
    expect(runner).to have_received(:call).once
    expect(errors.string).to include("non-retryable failure")
  end
end

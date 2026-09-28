require "rails_helper"
require "uri"
require_relative "../../lib/neon_deployment/preflight"

RSpec.describe NeonDeployment::Preflight do
  let(:connections) { [] }
  let(:connection_factory) do
    lambda do |url|
      FakeConnection.new(url, server_version_num: 180006).tap { |connection| connections << connection }
    end
  end
  let(:preflight) { described_class.new(environment:, connection_factory:) }
  let(:environment) { neon_environment }

  it "confere quatro bancos distintos no endpoint direto de produção" do
    expect { preflight.call! }.not_to raise_error
    expect(connections.length).to eq(8)
    expect(connections.map { |connection| URI.parse(connection.url).host }.uniq).to contain_exactly(
      "ep-main.c-2.sa-east-1.aws.neon.tech",
      "ep-main-pooler.c-2.sa-east-1.aws.neon.tech"
    )
    expect(connections).to all(be_closed)
  end

  it "aceita o projeto demo somente quando o banco principal é o banco autorizado" do
    demo_environment = neon_environment(demo: true)
    demo_preflight = described_class.new(environment: demo_environment, connection_factory:)

    expect { demo_preflight.call! }.not_to raise_error
    expect(connections.length).to eq(8)
  end

  it "rejeita URL ausente antes de abrir conexões" do
    incomplete_environment = neon_environment.merge("QUEUE_DATABASE_URL" => nil)

    expect { described_class.new(environment: incomplete_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /QUEUE_DATABASE_URL/)
    expect(connections).to be_empty
  end

  it "rejeita nome auxiliar ausente antes de abrir conexões" do
    incomplete_environment = neon_environment.merge("QUITANDO_QUEUE_DATABASE_NAME" => nil)

    expect { described_class.new(environment: incomplete_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /QUITANDO_QUEUE_DATABASE_NAME/)
    expect(connections).to be_empty
  end

  it "rejeita URI inválida antes de abrir conexões" do
    invalid_environment = neon_environment.merge("DATABASE_URL" => "postgresql://bad host/db")

    expect { described_class.new(environment: invalid_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /DATABASE_URL/)
    expect(connections).to be_empty
  end

  it "rejeita parâmetros que podem substituir o nome do banco" do
    injected_url = neon_url("ep-main-pooler.c-2.sa-east-1.aws.neon.tech", "Quitando", extra: "dbname=Demo&")
    invalid_environment = neon_environment.merge("DATABASE_URL" => injected_url)

    expect { described_class.new(environment: invalid_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /DATABASE_URL/)
    expect(connections).to be_empty
  end

  it "rejeita URLs auxiliares que apontam para outro projeto antes de conectar" do
    crossed_url = neon_url("ep-demo-pooler.c-2.sa-east-1.aws.neon.tech", "quitando_queue")
    invalid_environment = neon_environment.merge("QUEUE_DATABASE_URL" => crossed_url)

    expect { described_class.new(environment: invalid_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /QUEUE_DATABASE_URL/)
    expect(connections).to be_empty
  end

  it "rejeita um par completo de URLs auxiliares apontado para outro projeto" do
    invalid_environment = neon_environment.merge(
      "QUEUE_DATABASE_URL" => neon_url("ep-demo-pooler.c-2.sa-east-1.aws.neon.tech", "quitando_queue"),
      "QUITANDO_DIRECT_QUEUE_DATABASE_URL" => neon_url("ep-demo.c-2.sa-east-1.aws.neon.tech", "quitando_queue")
    )

    expect { described_class.new(environment: invalid_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /same Neon project/)
    expect(connections).to be_empty
  end

  it "rejeita parâmetros de conexão duplicados" do
    invalid_url = "postgresql://owner:secret@ep-main-pooler.c-2.sa-east-1.aws.neon.tech/Quitando?sslmode=disable&sslmode=require&channel_binding=require"
    invalid_environment = neon_environment.merge("DATABASE_URL" => invalid_url)

    expect { described_class.new(environment: invalid_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /DATABASE_URL/)
    expect(connections).to be_empty
  end

  it "rejeita pares direto e pooler que apontam para bancos diferentes" do
    invalid_environment = neon_environment.merge(
      "QUITANDO_DIRECT_CACHE_DATABASE_URL" => neon_url("ep-main.c-2.sa-east-1.aws.neon.tech", "wrong_cache")
    )

    expect { described_class.new(environment: invalid_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /CACHE_DATABASE_URL/)
    expect(connections).to be_empty
  end

  it "rejeita bancos repetidos para dois serviços" do
    invalid_environment = neon_environment.merge(
      "QUEUE_DATABASE_URL" => neon_url("ep-main-pooler.c-2.sa-east-1.aws.neon.tech", "quitando_cache"),
      "QUITANDO_DIRECT_QUEUE_DATABASE_URL" => neon_url("ep-main.c-2.sa-east-1.aws.neon.tech", "quitando_cache")
    )

    expect { described_class.new(environment: invalid_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /distinct/)
    expect(connections).to be_empty
  end

  it "rejeita banco auxiliar que não corresponde ao serviço antes de conectar" do
    invalid_environment = neon_environment.merge(
      "QUEUE_DATABASE_URL" => neon_url("ep-main-pooler.c-2.sa-east-1.aws.neon.tech", "wrong_queue"),
      "QUITANDO_DIRECT_QUEUE_DATABASE_URL" => neon_url("ep-main.c-2.sa-east-1.aws.neon.tech", "wrong_queue")
    )

    expect { described_class.new(environment: invalid_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /QUEUE_DATABASE_URL/)
    expect(connections).to be_empty
  end

  it "rejeita modo demo se o nome autorizado não corresponder ao banco principal" do
    invalid_environment = neon_environment(demo: true).merge("QUITANDO_DEMO_DATABASE_NAME" => "Outro")

    expect { described_class.new(environment: invalid_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /QUITANDO_DEMO_DATABASE_NAME/)
    expect(connections).to be_empty
  end

  it "rejeita projeto demo quando o modo demo está desligado" do
    invalid_environment = neon_environment(demo: true).merge("QUITANDO_DEMO_MODE" => "false")

    expect { described_class.new(environment: invalid_environment, connection_factory:).call! }
      .to raise_error(NeonDeployment::ConfigurationError, /QUITANDO_MAIN_DATABASE_NAME/)
    expect(connections).to be_empty
  end

  it "rejeita servidor que não seja PostgreSQL 18" do
    old_server_factory = ->(url) { FakeConnection.new(url, server_version_num: 170006) }

    expect { described_class.new(environment:, connection_factory: old_server_factory).call! }
      .to raise_error(NeonDeployment::ConnectionError, /PostgreSQL 18/)
  end

  it "não propaga credenciais nem detalhes de host quando uma conexão falha" do
    failing_factory = ->(_url) { raise PG::ConnectionBad, "password=secret host=ep-main" }
    error = nil

    expect { described_class.new(environment:, connection_factory: failing_factory).call! }
      .to raise_error(NeonDeployment::ConnectionError) { |exception| error = exception }
    expect(error.message).to include("QUITANDO_DIRECT_DATABASE_URL")
    expect(error.message).not_to match(/secret|ep-main/)
  end

  def neon_environment(demo: false)
    db_names = demo ? [ "Demo", "demo_cache", "demo_queue", "demo_cable" ] : [ "Quitando", "quitando_cache", "quitando_queue", "quitando_cable" ]
    direct_host = demo ? "ep-demo.c-2.sa-east-1.aws.neon.tech" : "ep-main.c-2.sa-east-1.aws.neon.tech"
    pooled_host = demo ? "ep-demo-pooler.c-2.sa-east-1.aws.neon.tech" : "ep-main-pooler.c-2.sa-east-1.aws.neon.tech"
    names = %w[primary cache queue cable]
    environment = {
      "QUITANDO_DEMO_MODE" => demo ? "true" : "false",
      "QUITANDO_DEMO_DATABASE_NAME" => demo ? "Demo" : nil,
      "QUITANDO_MAIN_DATABASE_NAME" => demo ? nil : "Quitando",
      "QUITANDO_CACHE_DATABASE_NAME" => demo ? "demo_cache" : "quitando_cache",
      "QUITANDO_QUEUE_DATABASE_NAME" => demo ? "demo_queue" : "quitando_queue",
      "QUITANDO_CABLE_DATABASE_NAME" => demo ? "demo_cable" : "quitando_cable"
    }

    names.each_with_index do |name, index|
      runtime_variable = name == "primary" ? "DATABASE_URL" : "#{name.upcase}_DATABASE_URL"
      direct_variable = name == "primary" ? "QUITANDO_DIRECT_DATABASE_URL" : "QUITANDO_DIRECT_#{name.upcase}_DATABASE_URL"
      environment[runtime_variable] = neon_url(pooled_host, db_names[index])
      environment[direct_variable] = neon_url(direct_host, db_names[index])
    end

    environment
  end

  def neon_url(host, database, extra: "")
    "postgresql://owner:secret@#{host}/#{database}?#{extra}sslmode=require&channel_binding=require"
  end

  class FakeConnection
    attr_reader :closed, :url

    def initialize(url, server_version_num:)
      @url = url
      @database_name = URI.parse(url).path.delete_prefix("/")
      @server_version_num = server_version_num
      @closed = false
    end

    def exec(_sql)
      [ { "database_name" => @database_name, "server_version_num" => @server_version_num.to_s } ]
    end

    def close
      @closed = true
    end

    def closed?
      closed
    end
  end
end

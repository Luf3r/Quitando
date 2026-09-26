class LocalEnvironmentRouter
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless LocalEnvironment.dual_database?

    shard = LocalEnvironment.shard_for_host(Rack::Request.new(env).host)
    return [ 400, { "content-type" => "text/plain; charset=utf-8" }, [ "Host não autorizado" ] ] unless shard

    ApplicationRecord.connected_to(role: :writing, shard:) { @app.call(env) }
  end
end

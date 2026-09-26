module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :environment_shard

    def connect
      self.environment_shard = if LocalEnvironment.dual_database?
        LocalEnvironment.shard_for_host(request.host)
      else
        :default
      end
      reject_unauthorized_connection unless environment_shard

      ApplicationRecord.connected_to(role: :writing, shard: environment_shard) do
        self.current_user = env["warden"]&.user
      end
      reject_unauthorized_connection unless current_user
    end
  end
end

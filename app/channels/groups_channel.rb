class GroupsChannel < ApplicationCable::Channel
  extend Turbo::Streams::StreamName
  include Turbo::Streams::StreamName::ClassMethods

  def subscribed
    shard = connection.respond_to?(:environment_shard) ? connection.environment_shard : nil
    shard ||= ApplicationRecord.current_shard

    ApplicationRecord.connected_to(role: :writing, shard:) do
      subscribe_in_environment
    end
  end

  private

  def subscribe_in_environment
    return reject unless current_user

    stream_name = verified_stream_name_from_params
    return reject unless CanonicalUuidV7RouteConstraint::UUID_V7_PATTERN.match?(stream_name)

    group = Group.find_by(id: stream_name)
    return reject unless group
    return reject unless Membership.active.exists?(group_id: group.id, user_id: current_user.id)

    stream_from LocalEnvironment.stream_name(stream_name)
  end
end

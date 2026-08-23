class GroupsChannel < ApplicationCable::Channel
  extend Turbo::Streams::StreamName
  include Turbo::Streams::StreamName::ClassMethods

  def subscribed
    return reject unless current_user

    stream_name = verified_stream_name_from_params
    return reject unless CanonicalUuidV7RouteConstraint::UUID_V7_PATTERN.match?(stream_name)

    group = Group.find_by(id: stream_name)
    return reject unless group
    return reject unless Membership.active.exists?(group_id: group.id, user_id: current_user.id)

    stream_from stream_name
  end
end

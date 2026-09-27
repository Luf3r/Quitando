Rails.application.reloader.to_prepare do
  next if Rails.configuration.x.group_realtime_broadcaster_subscriber

  Rails.configuration.x.group_realtime_broadcaster_subscriber = ActiveSupport::Notifications.subscribe("quitando.group.state_changed") do |event|
    GroupRealtimeBroadcaster.call(event.payload)
  end
end

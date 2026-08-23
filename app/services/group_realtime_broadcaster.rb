class GroupRealtimeBroadcaster
  EVENT_NAME = GroupStateChanged::EVENT_NAME
  NOTICE_BY_CHANGE_TYPE = GroupStateChanged::CHANGE_TYPES.index_with { "O estado do grupo foi atualizado." }.freeze

  class << self
    def call(payload)
      notice = NOTICE_BY_CHANGE_TYPE.fetch(payload.fetch(:change_type))
      request_id = Turbo.current_request_id if Turbo.respond_to?(:current_request_id)
      content = [ notice_stream(notice), refresh_stream(request_id) ].join

      ActionCable.server.broadcast(payload.fetch(:group_id), content)
    rescue StandardError => error
      Rails.error.report(
        error,
        handled: true,
        severity: :error,
        context: safe_context(payload),
        source: EVENT_NAME
      )
      nil
    end

    def schedule_reconnection(user_id)
      ActiveRecord.after_all_transactions_commit do
        ActionCable.server.remote_connections.where(current_user: User.find(user_id)).disconnect(reconnect: true)
      rescue StandardError => error
        Rails.error.report(
          error,
          handled: true,
          severity: :error,
          context: { subject_user_id: user_id },
          source: EVENT_NAME
        )
      end
    end

    private

    def notice_stream(notice)
      %(<turbo-stream action="append" target="group_remote_notice"><template><p>#{ERB::Util.html_escape(notice)}</p></template></turbo-stream>)
    end

    def refresh_stream(request_id)
      attribute = request_id.present? ? %( request-id="#{ERB::Util.html_escape(request_id)}") : ""
      %(<turbo-stream action="refresh"#{attribute}></turbo-stream>)
    end

    def safe_context(payload)
      payload.slice(:group_id, :actor_user_id, :change_type, :subject_user_id, :financial_state_version)
    end
  end
end

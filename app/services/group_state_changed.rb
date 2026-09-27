class GroupStateChanged
  EVENT_NAME = "quitando.group.state_changed"
  CHANGE_TYPES = %i[
    expense_created expense_description_changed expense_corrected
    payment_reported payment_confirmed payment_cancelled
    group_created group_renamed group_archived group_restored
    invitation_created invitation_revoked invitation_accepted invitation_declined
    membership_deactivated membership_reactivated membership_reordered ownership_transferred
  ].freeze

  class << self
    def publish(group_id:, actor_user_id:, change_type:, subject_user_id: nil, financial_state_version: nil)
      raise ArgumentError, "tipo de mudança inválido" unless CHANGE_TYPES.include?(change_type)

      payload = {
        group_id:,
        actor_user_id:,
        change_type:,
        **(subject_user_id ? { subject_user_id: } : {}),
        **(!financial_state_version.nil? ? { financial_state_version: } : {})
      }.freeze

      ActiveRecord.after_all_transactions_commit do
        ActiveSupport::Notifications.instrument(EVENT_NAME, payload)
      rescue StandardError => error
        Rails.error.report(
          error,
          handled: true,
          severity: :error,
          context: payload,
          source: EVENT_NAME
        )
      end
    end
  end
end

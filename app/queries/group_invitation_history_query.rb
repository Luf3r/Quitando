class GroupInvitationHistoryQuery
  Page = Data.define(:entries, :number, :total_pages, :total_facts)
  PER_PAGE = 25

  def self.pending_page(invitations:, number:)
    page(invitations.pending.reorder(created_at: :desc, id: :desc), number:)
  end

  def self.terminal_page(invitations:, number:)
    terminal_timestamp = "COALESCE(accepted_at, declined_at, revoked_at, expired_at)"
    page(invitations.where.not(status: :pending).reorder(Arel.sql("#{terminal_timestamp} DESC"), id: :desc), number:)
  end

  def self.page(invitations, number:)
    total_facts = invitations.count
    total_pages = [ (total_facts + PER_PAGE - 1) / PER_PAGE, 1 ].max
    entries = invitations.includes(:group, :invited_user, :invited_by_user).limit(PER_PAGE).offset((number - 1) * PER_PAGE).to_a

    Page.new(entries:, number:, total_pages:, total_facts:)
  end
  private_class_method :page
end

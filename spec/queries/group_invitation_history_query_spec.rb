require "rails_helper"

RSpec.describe GroupInvitationHistoryQuery do
  describe ".pending_page" do
    it "pagina vinte e cinco convites pendentes por created_at e id decrescentes" do
      user = create(:user)
      timestamp = Time.zone.parse("2026-08-28 10:00:00")
      invitations = create_list(:group_invitation, 26, invited_user: user, created_at: timestamp)

      first_page = described_class.pending_page(invitations: GroupInvitation.where(invited_user: user), number: 1)
      second_page = described_class.pending_page(invitations: GroupInvitation.where(invited_user: user), number: 2)
      expected = invitations.sort_by { |invitation| [ invitation.created_at, invitation.id ] }.reverse

      expect(first_page).to have_attributes(number: 1, total_pages: 2, total_facts: 26)
      expect(first_page.entries).to eq(expected.first(25))
      expect(second_page.entries).to eq(expected.last(1))
    end
  end

  describe ".terminal_page" do
    it "pagina vinte e cinco convites terminais" do
      user = create(:user)
      timestamp = Time.zone.parse("2026-08-28 10:00:00")
      invitations = create_list(:group_invitation, 26, :declined, invited_user: user, declined_at: timestamp)

      first_page = described_class.terminal_page(invitations: GroupInvitation.where(invited_user: user), number: 1)
      second_page = described_class.terminal_page(invitations: GroupInvitation.where(invited_user: user), number: 2)
      expected = invitations.sort_by { |invitation| [ invitation.declined_at, invitation.id ] }.reverse

      expect(first_page).to have_attributes(number: 1, total_pages: 2, total_facts: 26)
      expect(first_page.entries).to eq(expected.first(25))
      expect(second_page.entries).to eq(expected.last(1))
    end

    it "ordena os convites terminais pelo seu timestamp terminal e id decrescentes" do
      user = create(:user)
      early = Time.zone.parse("2026-08-28 09:00:00")
      late = Time.zone.parse("2026-08-28 10:00:00")
      invitations = [
        create(:group_invitation, :accepted, invited_user: user, accepted_at: late),
        create(:group_invitation, :declined, invited_user: user, declined_at: late),
        create(:group_invitation, :revoked, invited_user: user, revoked_at: late),
        create(:group_invitation, :expired, invited_user: user, expired_at: early)
      ]

      page = described_class.terminal_page(invitations: GroupInvitation.where(invited_user: user), number: 1)
      expected = invitations.sort_by { |invitation| [ invitation.accepted_at || invitation.declined_at || invitation.revoked_at || invitation.expired_at, invitation.id ] }.reverse

      expect(page).to have_attributes(number: 1, total_pages: 1, total_facts: 4)
      expect(page.entries).to eq(expected)
    end
  end
end

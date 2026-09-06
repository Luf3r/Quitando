require "rails_helper"

RSpec.describe GroupOverviewPresenter do
  def snapshot_for(status:, official:, projected: official, pending: [], plan: [])
    GroupOverviewQuery::Snapshot.new(
      official_balances: official,
      projected_balances: projected,
      pending_payments: pending,
      settlement_plan: plan,
      recent_entries: [],
      memberships: [],
      participant_names: official.keys.index_with { |id| "Pessoa #{id}" },
      status:
    )
  end

  it "prioriza a revisão de um recebimento antes de qualquer outra ação" do
    viewer_id = SecureRandom.uuid
    other_id = SecureRandom.uuid
    payment = build_stubbed(:payment, :reported, from_user_id: other_id, to_user_id: viewer_id)
    snapshot = snapshot_for(status: :awaiting_confirmation, official: { viewer_id => 0, other_id => 0 }, pending: [ payment ])

    presenter = described_class.new(snapshot:, viewer_id:, archived: false)

    expect(presenter.primary_action).to eq(:review_received)
    expect(presenter.personal_pending.map(&:payment)).to eq([ payment ])
    expect(presenter.waiting_pending).to be_empty
  end

  it "mostra projeção apenas quando ela diverge do saldo oficial" do
    viewer_id = SecureRandom.uuid
    other_id = SecureRandom.uuid
    snapshot = snapshot_for(status: :open, official: { viewer_id => -100, other_id => 100 }, projected: { viewer_id => -50, other_id => 50 })

    presenter = described_class.new(snapshot:, viewer_id:, archived: false)

    expect(presenter.viewer_official_cents).to eq(-100)
    expect(presenter.viewer_projected_cents).to eq(-50)
    expect(presenter.show_viewer_projection?).to be(true)
    expect(presenter.participants.first.to_h).to include(name: "Pessoa #{viewer_id}")
    expect(presenter.participants).to include(an_object_having_attributes(user_id: viewer_id, official_cents: -100, projected_cents: -50, show_projection: true))
  end

  it "cobre os estados vazio, em aberto, aguardando, quitado e arquivado" do
    viewer_id = SecureRandom.uuid
    other_id = SecureRandom.uuid
    transfer = DebtSimplifier::Transfer.new(from_user_id: viewer_id, to_user_id: other_id, amount_cents: 100)

    expect(described_class.new(snapshot: snapshot_for(status: :empty, official: { viewer_id => 0 }), viewer_id:, archived: false).primary_action).to eq(:add_expense)
    expect(described_class.new(snapshot: snapshot_for(status: :open, official: { viewer_id => -100, other_id => 100 }, plan: [ transfer ]), viewer_id:, archived: false).primary_action).to eq(:report_transfer)
    expect(described_class.new(snapshot: snapshot_for(status: :awaiting_confirmation, official: { viewer_id => 0 }), viewer_id:, archived: false).primary_action).to eq(:wait_for_others)
    expect(described_class.new(snapshot: snapshot_for(status: :settled, official: { viewer_id => 0 }), viewer_id:, archived: false).primary_action).to eq(:settled)
    expect(described_class.new(snapshot: snapshot_for(status: :settled, official: { viewer_id => 0 }), viewer_id:, archived: true).primary_action).to eq(:archived)
  end
end

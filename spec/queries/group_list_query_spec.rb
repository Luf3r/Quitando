require "rails_helper"

RSpec.describe GroupListQuery do
  it "prioriza recebimentos, envios e pendências alheias sem executar o simplificador" do
    ana = create(:user, email: "ana@example.com")
    bruno = create(:user, email: "bruno@example.com")
    carla = create(:user, email: "carla@example.com")
    received_group = GroupCreator.call(owner_user_id: ana.id, name: "Receber")
    sent_group = GroupCreator.call(owner_user_id: ana.id, name: "Enviar")
    other_group = GroupCreator.call(owner_user_id: ana.id, name: "Aguardar")

    [ received_group, sent_group, other_group ].each do |group|
      create(:membership, group:, user: bruno, position: 1)
      create(:membership, group:, user: carla, position: 2)
    end

    create(:payment, :reported, group: received_group, from_user: bruno, to_user: ana, reported_by_user: bruno)
    create(:payment, :reported, group: sent_group, from_user: ana, to_user: bruno, reported_by_user: ana)
    create(:payment, :reported, group: other_group, from_user: bruno, to_user: carla, reported_by_user: bruno)

    expect(DebtSimplifier).not_to receive(:new)

    cards = described_class.call(groups: Group.where(id: [ other_group.id, sent_group.id, received_group.id ]), viewer: ana)

    expect(cards.map { |card| [ card.group.name, card.pending_received_count, card.pending_sent_count, card.pending_other_count, card.attention_rank ] }).to eq(
      [
        [ "Receber", 1, 0, 0, 1 ],
        [ "Enviar", 0, 1, 0, 2 ],
        [ "Aguardar", 0, 0, 1, 4 ]
      ]
    )
  end

  it "compõe cards sem executar o simplificador" do
    ana = create(:user, email: "ana@example.com")
    bruno = create(:user, email: "bruno@example.com")
    group = GroupCreator.call(owner_user_id: ana.id, name: "Apartamento")
    create(:membership, group:, user: bruno, position: 1)

    expect(DebtSimplifier).not_to receive(:new)

    cards = described_class.call(groups: Group.where(id: group.id), viewer: ana)

    expect(cards).to contain_exactly(
      have_attributes(
        group:,
        memberships: contain_exactly(have_attributes(user: ana), have_attributes(user: bruno)),
        status: :empty,
        viewer_balance_cents: 0,
        pending_payment_count: 0,
        archived: false
      )
    )
  end

  it "ordena saldo aberto, grupos aguardando, vazios, quitados e arquivados de forma determinística" do
    ana = create(:user, email: "ana@example.com")
    bruno = create(:user, email: "bruno@example.com")
    open_group = GroupCreator.call(owner_user_id: ana.id, name: "Aberto")
    awaiting_group = GroupCreator.call(owner_user_id: ana.id, name: "Aguardando")
    empty_group = GroupCreator.call(owner_user_id: ana.id, name: "Vazio")
    settled_group = GroupCreator.call(owner_user_id: ana.id, name: "Quitado")
    archived_group = GroupCreator.call(owner_user_id: ana.id, name: "Arquivado")

    [ open_group, awaiting_group, settled_group ].each { |group| create(:membership, group:, user: bruno, position: 1) }
    open_expense = create(:expense, group: open_group, paid_by_user: ana, created_by_user: ana, amount_cents: 100)
    create(:expense_share, expense: open_expense, user: bruno, amount_owed_cents: 100, position: 0)
    create(:payment, :reported, group: awaiting_group, from_user: bruno, to_user: ana, reported_by_user: bruno)
    first_expense = create(:expense, group: settled_group, paid_by_user: ana, created_by_user: ana, amount_cents: 100)
    create(:expense_share, expense: first_expense, user: bruno, amount_owed_cents: 100, position: 0)
    second_expense = create(:expense, group: settled_group, paid_by_user: bruno, created_by_user: bruno, amount_cents: 100)
    create(:expense_share, expense: second_expense, user: ana, amount_owed_cents: 100, position: 0)
    archived_group.update!(archived_at: Time.current)

    cards = described_class.call(groups: Group.where(id: [ archived_group, settled_group, empty_group, awaiting_group, open_group ]), viewer: ana)

    expect(cards.map { |card| [ card.group.name, card.attention_rank ] }).to eq(
      [ [ "Aguardando", 1 ], [ "Aberto", 3 ], [ "Vazio", 5 ], [ "Quitado", 6 ], [ "Arquivado", 7 ] ]
    )
  end
end

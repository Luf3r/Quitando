require "rails_helper"

RSpec.describe "ExpenseDescriptionEditor" do
  it "registra a revisão e preserva a versão financeira" do
    group = create(:group)
    creator = create(:user)
    participant = create(:user)
    create(:membership, group:, user: creator, role: :owner, position: 0)
    create(:membership, group:, user: participant, position: 1)
    expense = ExpenseCreator.call(
      group_id: group.id, created_by_user_id: creator.id, paid_by_user_id: creator.id,
      description: "Mercado", occurred_on: Date.new(2026, 8, 4), amount_text: "2,00",
      split: { type: :exact, shares: [ { user_id: creator.id, amount_text: "1,00" }, { user_id: participant.id, amount_text: "1,00" } ] }
    )

    expect(Group).to receive(:lock).and_call_original

    edited = ExpenseDescriptionEditor.call(group_id: group.id, expense_id: expense.id, actor_user_id: creator.id, description: "Mercado da semana")

    expect(edited.reload.description).to eq("Mercado da semana")
    expect(ExpenseDescriptionRevision.where(expense:)).to contain_exactly(
      have_attributes(actor_user_id: creator.id, previous_description: "Mercado", new_description: "Mercado da semana")
    )
    expect(group.reload.financial_state_version).to eq(1)
  end

  it "permite ao pagador ativo editar a descrição de uma despesa anulada" do
    group = create(:group)
    creator = create(:user)
    payer = create(:user)
    create(:membership, group:, user: creator, role: :owner, position: 0)
    create(:membership, group:, user: payer, position: 1)
    expense = create(:expense, :voided, group:, created_by_user: creator, paid_by_user: payer, voided_by_user: creator, description: "Mercado")

    edited = ExpenseDescriptionEditor.call(group_id: group.id, expense_id: expense.id, actor_user_id: payer.id, description: "Mercado de domingo")

    expect(edited.reload).to have_attributes(description: "Mercado de domingo", voided_at: expense.voided_at, voided_by_user_id: creator.id)
    expect(edited.expense_description_revisions).to contain_exactly(
      have_attributes(actor_user_id: payer.id, previous_description: "Mercado", new_description: "Mercado de domingo")
    )
    expect(group.reload.financial_state_version).to eq(0)
  end

  it "rejeita descrição idêntica sem criar uma revisão" do
    group = create(:group)
    creator = create(:user)
    create(:membership, group:, user: creator, role: :owner, position: 0)
    expense = create(:expense, group:, created_by_user: creator, paid_by_user: creator, description: "Mercado")

    expect {
      ExpenseDescriptionEditor.call(group_id: group.id, expense_id: expense.id, actor_user_id: creator.id, description: "Mercado")
    }.to raise_error(ExpenseDescriptionEditor::InvalidInput, "descrição inalterada")

    expect(ExpenseDescriptionRevision.where(expense:)).to be_empty
    expect(expense.reload.description).to eq("Mercado")
    expect(group.reload.financial_state_version).to eq(0)
  end

  it "rejeita membro ativo sem relação com a despesa" do
    group = create(:group)
    creator = create(:user)
    outsider = create(:user)
    create(:membership, group:, user: creator, role: :owner, position: 0)
    create(:membership, group:, user: outsider, position: 1)
    expense = create(:expense, group:, created_by_user: creator, paid_by_user: creator, description: "Mercado")

    expect {
      ExpenseDescriptionEditor.call(group_id: group.id, expense_id: expense.id, actor_user_id: outsider.id, description: "Mercado editado")
    }.to raise_error(ExpenseDescriptionEditor::Forbidden, "ator não autorizado")

    expect(ExpenseDescriptionRevision.where(expense:)).to be_empty
    expect(expense.reload.description).to eq("Mercado")
  end

  it "rejeita o creator inativo sem criar uma revisão" do
    group = create(:group)
    creator = create(:user)
    membership = create(:membership, group:, user: creator, role: :owner, position: 0)
    expense = create(:expense, group:, created_by_user: creator, paid_by_user: creator, description: "Mercado")
    membership.update!(status: :inactive)

    expect {
      ExpenseDescriptionEditor.call(group_id: group.id, expense_id: expense.id, actor_user_id: creator.id, description: "Mercado editado")
    }.to raise_error(ExpenseDescriptionEditor::Forbidden, "membership ativa obrigatória")

    expect(ExpenseDescriptionRevision.where(expense:)).to be_empty
    expect(expense.reload.description).to eq("Mercado")
  end

  it "rejeita edição em grupo arquivado sem criar uma revisão" do
    group = create(:group, archived_at: Time.current)
    creator = create(:user)
    create(:membership, group:, user: creator, role: :owner, position: 0)
    expense = create(:expense, group:, created_by_user: creator, paid_by_user: creator, description: "Mercado")

    expect {
      ExpenseDescriptionEditor.call(group_id: group.id, expense_id: expense.id, actor_user_id: creator.id, description: "Mercado editado")
    }.to raise_error(ExpenseDescriptionEditor::ArchivedGroup, "grupo arquivado")

    expect(ExpenseDescriptionRevision.where(expense:)).to be_empty
    expect(expense.reload.description).to eq("Mercado")
  end
end

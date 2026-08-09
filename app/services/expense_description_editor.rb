class ExpenseDescriptionEditor
  class InvalidInput < ArgumentError; end
  class Forbidden < StandardError; end
  class NotFound < StandardError; end
  class ArchivedGroup < StandardError; end

  UUID_V7_PATTERN = ExpenseCorrector::UUID_V7_PATTERN

  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(group_id:, expense_id:, actor_user_id:, description:)
    @group_id = group_id
    @expense_id = expense_id
    @actor_user_id = actor_user_id
    @description = description
  end

  def call
    validate_input!

    Group.transaction do
      group = Group.lock.find_by(id: group_id) || raise(NotFound, "grupo não encontrado")
      raise ArchivedGroup, "grupo arquivado" if group.archived_at?
      raise Forbidden, "membership ativa obrigatória" unless Membership.where(group:, user_id: actor_user_id, status: :active).exists?
      expense = group.expenses.lock.find_by(id: expense_id) || raise(NotFound, "despesa não encontrada")
      raise Forbidden, "ator não autorizado" unless authorized?(group, expense)
      raise InvalidInput, "descrição inalterada" if expense.description == description

      ExpenseDescriptionRevision.create!(expense:, actor_user_id:, previous_description: expense.description, new_description: description)
      expense.update!(description:)
      expense
    end
  end

  private

  attr_reader :group_id, :expense_id, :actor_user_id, :description

  def validate_input!
    raise InvalidInput, "identificadores inválidos" unless [ group_id, expense_id, actor_user_id ].all? { |id| id.is_a?(String) && UUID_V7_PATTERN.match?(id) }
    raise InvalidInput, "descrição inválida" unless description.is_a?(String) && description.strip.present?
  end

  def authorized?(group, expense)
    actor_user_id == expense.created_by_user_id || actor_user_id == expense.paid_by_user_id || Membership.where(group:, user_id: actor_user_id, role: :owner, status: :active).exists?
  end
end

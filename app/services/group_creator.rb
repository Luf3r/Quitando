class GroupCreator < GroupCommand
  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(owner_user_id:, name:)
    @owner_user_id = owner_user_id
    @name = name
  end

  def call
    validate_persisted_ids!(owner_user_id)
    normalized_name = normalize_name!(name)

    Group.transaction do
      owner = User.find_by(id: owner_user_id) || raise(NotFound, "usuário não encontrado")
      group = Group.create!(name: normalized_name, currency_code: "BRL")
      Membership.create!(group:, user: owner, role: :owner, status: :active, position: 0)
      group
    end
  end

  private

  attr_reader :owner_user_id, :name
end

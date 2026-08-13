class GroupCommand
  class InvalidInput < ArgumentError; end
  class Forbidden < StandardError; end
  class NotFound < StandardError; end
  class ArchivedGroup < StandardError; end
  class InvalidTransition < StandardError; end

  UUID_V7_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  private

  def validate_persisted_ids!(*ids)
    raise InvalidInput, "identificadores inválidos" unless ids.all? { |id| id.is_a?(String) && UUID_V7_PATTERN.match?(id) }
  end

  def normalize_name!(name)
    raise InvalidInput, "nome inválido" unless name.is_a?(String)

    normalized_name = name.strip
    raise InvalidInput, "nome inválido" if normalized_name.empty?

    normalized_name
  end
end

require "digest"
require "json"

class FinancialCommand
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
  UUID_V7_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  private

  def validate_persisted_ids!(*ids)
    raise PaymentCommand::InvalidInput, "identificadores inválidos" unless ids.all? { |id| id.is_a?(String) && UUID_V7_PATTERN.match?(id) }
  end

  def validate_idempotency_key!(key)
    raise PaymentCommand::InvalidInput, "chave de idempotência inválida" unless key.is_a?(String) && UUID_PATTERN.match?(key)
  end

  def validate_expected_version!(version)
    raise PaymentCommand::InvalidInput, "versão financeira inválida" unless version.is_a?(Integer) && version >= 0
  end

  def fingerprint(vector)
    Digest::SHA256.hexdigest(JSON.generate(vector))
  end

  def active_member?(group, user_id)
    Membership.where(group:, user_id:, status: :active).exists?
  end
end

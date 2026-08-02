class SettlementPlanTextPresenter
  def self.call(transfers)
    transfers.map do |transfer|
      "#{transfer.from_user_id} paga #{transfer.amount_cents} centavos para #{transfer.to_user_id}"
    end
  end
end

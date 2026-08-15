module Http
  class DomainErrorMapper
    ErrorResponse = Data.define(:status, :i18n_key, :field)

    def self.call(error)
      case error
      when GroupCommand::InvalidInput, GroupCommand::ArchivedGroup, GroupCommand::InvalidTransition, ExpenseCreator::InvalidExpense
        ErrorResponse.new(status: :unprocessable_entity, i18n_key: "errors.unprocessable_entity", field: :name)
      when ExpenseCorrector::InvalidExpense, ExpenseCorrector::ArchivedGroup, ExpenseDescriptionEditor::InvalidInput, ExpenseDescriptionEditor::ArchivedGroup
        ErrorResponse.new(status: :unprocessable_entity, i18n_key: "errors.unprocessable_entity", field: :expense)
      when ExpenseCorrector::StaleFinancialState, ExpenseCorrector::IdempotencyConflict
        ErrorResponse.new(status: :conflict, i18n_key: "errors.conflict", field: :financial_state_version)
      else
        raise error
      end
    end
  end
end

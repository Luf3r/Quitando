module Http
  class DomainErrorMapper
    ErrorResponse = Data.define(:status, :i18n_key, :field)

    def self.call(error)
      case error
      when GroupCommand::InvalidInput, GroupCommand::ArchivedGroup, GroupCommand::InvalidTransition
        ErrorResponse.new(status: :unprocessable_entity, i18n_key: "errors.unprocessable_entity", field: :name)
      else
        raise error
      end
    end
  end
end

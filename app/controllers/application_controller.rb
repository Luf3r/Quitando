class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  rescue_from ExpenseDescriptionEditor::Forbidden, ExpenseCorrector::Forbidden, with: :render_forbidden
  rescue_from PaymentCommand::Forbidden, with: :render_forbidden
  rescue_from GroupCommand::InvalidInput, GroupCommand::ArchivedGroup, GroupCommand::InvalidTransition, ExpenseCreator::InvalidExpense,
              ExpenseCorrector::InvalidExpense, ExpenseCorrector::ArchivedGroup, ExpenseCorrector::StaleFinancialState,
              ExpenseCorrector::IdempotencyConflict, ExpenseDescriptionEditor::InvalidInput, ExpenseDescriptionEditor::ArchivedGroup,
              PaymentCommand::InvalidInput, PaymentCommand::ArchivedGroup, PaymentCommand::SuggestionUnavailable,
              PaymentCommand::InvalidTransition, PaymentCommand::StaleFinancialState, PaymentCommand::IdempotencyConflict,
              with: :render_domain_error
  rescue_from ActionController::ParameterMissing, with: :render_unprocessable_entity

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def render_forbidden
    render plain: t("errors.forbidden"), status: :forbidden
  end

  def render_domain_error(error)
    response = Http::DomainErrorMapper.call(error)
    message = [ t(response.i18n_key), error.message.presence ].compact.join(" ")
    render plain: message, status: response.status
  end

  def render_unprocessable_entity
    render plain: t("errors.unprocessable_entity"), status: :unprocessable_entity
  end
end

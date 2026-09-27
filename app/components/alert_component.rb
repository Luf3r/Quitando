class AlertComponent < ApplicationComponent
  VARIANTS = %i[success info warning error].freeze

  def initialize(message:, variant: :error)
    @message = message
    @variant = VARIANTS.include?(variant.to_sym) ? variant.to_sym : :error
  end

  private

  attr_reader :message, :variant

  def role
    variant == :success ? "status" : "alert"
  end
end

class ButtonComponent < ApplicationComponent
  VARIANTS = %i[primary secondary quiet danger].freeze

  def initialize(label:, href: nil, variant: :primary, type: :button, disabled: false, data: {}, method: nil)
    @label = label
    @href = href
    @variant = VARIANTS.include?(variant.to_sym) ? variant.to_sym : :primary
    @type = type
    @disabled = disabled
    @data = data
    @method = method
  end

  private

  attr_reader :label, :href, :variant, :type, :disabled, :data, :method

  def classes
    class_names("ui-button", "ui-button--#{variant}", "ui-button--compact": variant == :secondary)
  end
end

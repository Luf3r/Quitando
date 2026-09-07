class ButtonComponent < ApplicationComponent
  VARIANTS = %i[primary secondary quiet danger].freeze
  SIZES = %i[default compact].freeze

  def initialize(label:, href: nil, variant: :primary, size: :default, type: :button, disabled: false, data: {}, method: nil)
    raise ArgumentError, "method requires href" if method.present? && href.blank?

    @label = label
    @href = href
    @variant = VARIANTS.include?(variant.to_sym) ? variant.to_sym : :primary
    @size = SIZES.include?(size.to_sym) ? size.to_sym : :default
    @type = type
    @disabled = disabled
    @data = data
    @method = method
  end

  private

  attr_reader :label, :href, :variant, :size, :type, :disabled, :data, :method

  def classes
    class_names("ui-button", "ui-button--#{variant}", "ui-button--#{size}")
  end
end

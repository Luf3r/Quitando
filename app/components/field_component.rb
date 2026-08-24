class FieldComponent < ApplicationComponent
  def initialize(label:, name:, value: nil, type: :text, hint: nil, errors: [], options: {})
    @label = label
    @name = name
    @value = value
    @type = type
    @hint = hint
    @errors = Array(errors).compact_blank
    @options = options
  end

  private

  attr_reader :label, :name, :value, :type, :hint, :errors, :options

  def field_id
    @field_id ||= name.gsub(/\]\[|\[|\]/, "_").delete_suffix("_")
  end

  def described_by
    [ ("#{field_id}_hint" if hint.present?), ("#{field_id}_error" if errors.any?) ].compact.join(" ").presence
  end
end

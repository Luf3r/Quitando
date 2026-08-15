class FormErrorsComponent < ApplicationComponent
  def initialize(messages:)
    @messages = Array(messages).compact_blank
  end

  def render?
    @messages.any?
  end
end

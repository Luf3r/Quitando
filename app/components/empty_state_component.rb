class EmptyStateComponent < ApplicationComponent
  def initialize(title:, body:, action_label: nil, action_path: nil)
    @title = title
    @body = body
    @action_label = action_label
    @action_path = action_path
  end
end

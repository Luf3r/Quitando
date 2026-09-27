class PageHeaderComponent < ApplicationComponent
  def initialize(title:, description: nil, action_label: nil, action_path: nil)
    @title = title
    @description = description
    @action_label = action_label
    @action_path = action_path
  end
end

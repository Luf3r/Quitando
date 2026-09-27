require "rails_helper"

RSpec.describe "Strings visíveis" do
  it "não usa em dash ou en dash em templates, componentes e traduções" do
    paths = %w[app/views app/components config/locales].flat_map do |directory|
      Dir[Rails.root.join(directory, "**", "*")].select { |path| File.file?(path) }
    end
    violations = paths.filter_map do |path|
      lines = File.readlines(path, chomp: true).each_with_index.filter_map do |line, index|
        "#{index + 1}:#{line.strip}" if line.match?(/[—–]/)
      end
      "#{Pathname(path).relative_path_from(Rails.root)}\n#{lines.join("\n")}" if lines.any?
    end

    expect(violations).to be_empty, "Remova em dash e en dash de strings visíveis:\n#{violations.join("\n")}"
  end
end

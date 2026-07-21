require "rails_helper"
require "base64"
require "image_processing/vips"
require "tempfile"

RSpec.describe "ImageProcessing com Vips" do
  it "configura Vips como processador de variantes do Active Storage" do
    expect(Rails.application.config.active_storage.variant_processor).to eq(:vips)
  end

  it "redimensiona uma imagem com ruby-vips" do
    input = Tempfile.new([ "input", ".png" ])
    input.binmode
    input.write(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL3fQAAAABJRU5ErkJggg=="))
    input.flush

    output = ImageProcessing::Vips.source(input.path).resize_to_fill(2, 2).convert("png").call
    transformed = Vips::Image.new_from_file(output.path)

    expect([ transformed.width, transformed.height ]).to eq([ 2, 2 ])
  ensure
    input&.close!
    output&.close!
  end
end

require "rails_helper"

RSpec.describe CanonicalUuidV7RouteConstraint do
  let(:canonical_uuid_v7) { "018f4f4d-1c3a-7c6b-8e9f-123456789abc" }

  it "aceita somente UUID v7 canônico no parâmetro configurado" do
    constraint = described_class.new(:group_id)

    expect(constraint.matches?(request_with(group_id: canonical_uuid_v7))).to be(true)
    expect(constraint.matches?(request_with(group_id: canonical_uuid_v7.upcase))).to be(false)
    expect(constraint.matches?(request_with(group_id: "018f4f4d-1c3a-6c6b-8e9f-123456789abc"))).to be(false)
  end

  it "rejeita a rota quando qualquer ID aninhado está ausente ou malformado" do
    constraint = described_class.new(:group_id, :id)

    expect(constraint.matches?(request_with(group_id: canonical_uuid_v7, id: canonical_uuid_v7))).to be(true)
    expect(constraint.matches?(request_with(group_id: canonical_uuid_v7, id: "invalido"))).to be(false)
    expect(constraint.matches?(request_with(group_id: canonical_uuid_v7))).to be(false)
  end

  def request_with(path_parameters)
    Struct.new(:path_parameters).new(path_parameters)
  end
end

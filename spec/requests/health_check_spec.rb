require "rails_helper"

RSpec.describe "Health check" do
  it "responde sem exigir um User-Agent artificial" do
    get rails_health_check_path

    expect(response).to have_http_status(:ok)
  end

  it "responde a um User-Agent típico de health probe" do
    get rails_health_check_path, headers: { "User-Agent" => "kube-probe/1.31" }

    expect(response).to have_http_status(:ok)
  end
end

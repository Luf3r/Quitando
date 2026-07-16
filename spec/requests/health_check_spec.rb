require "rails_helper"

RSpec.describe "Health check" do
  it "confirma que a aplicação inicia" do
    get rails_health_check_path, headers: { "User-Agent" => "Mozilla/5.0 Chrome/120.0.0.0 Safari/537.36" }

    expect(response).to have_http_status(:ok)
  end
end

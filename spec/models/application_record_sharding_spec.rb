require "rails_helper"

RSpec.describe ApplicationRecord do
  it "mantém conexões simultâneas para dados reais e de demonstração" do
    real_database = described_class.connection_db_config.database
    demo_database = described_class.connected_to(role: :writing, shard: :demo) do
      described_class.connection_db_config.database
    end

    expect(real_database).to eq("quitando_test")
    expect(demo_database).to eq("quitando_demo_test")
    expect(described_class.connection_db_config.database).to eq(real_database)
  end
end

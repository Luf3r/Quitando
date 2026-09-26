require "rails_helper"

RSpec.describe "Linguagem das telas financeiras" do
  it "explica envio, confirmação irreversível e plano com palavras do cotidiano" do
    user = create(:user)
    group = GroupCreator.call(owner_user_id: user.id, name: "Casa")
    other = create(:user)
    create(:membership, group:, user: other, position: 1)
    payment = create(:payment, group:, from_user: other, to_user: user, reported_by_user: other)
    post user_session_path, params: { user: { email: user.email, password: user.password } }

    get group_payment_path(group, payment)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css("main")&.text).to include("Aguardando confirmação", "Marcado como enviado por")
    expect(document.at_css("[data-turbo-confirm]")&.[]("data-turbo-confirm")).to include("não pode ser desfeita")
    expect(document.at_css("main")&.text).not_to match(/MVP|terminal/)

    get group_plan_path(group)
    expect(Nokogiri::HTML(response.body).at_css("main").text).to include("consideram os envios que aguardam confirmação")
    get group_path(group)
    expect(Nokogiri::HTML(response.body).at_css("#group_dashboard_financial_summary").text).to include("marcou como enviado")
  end
end

require "rails_helper"

RSpec.describe "Conta pessoal" do
  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: user.password } }
  end

  it "exige autenticação" do
    get account_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "mostra edição de e-mail e senha sem oferecer exclusão" do
    user = create(:user, email: "ana@example.com")
    sign_in_as user

    get account_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ana@example.com")
    expect(response.body).to include("Senha atual")
    expect(response.body).not_to match(/excluir conta|cancelar minha conta/i)
    expect(Nokogiri::HTML(response.body).at_css("form[action='/users'][method='post'] input[name='_method'][value='delete']")).to be_nil
  end

  it "atualiza o e-mail mediante senha atual" do
    user = create(:user, email: "ana@example.com", password: "senha-segura")
    sign_in_as user

    patch account_path, params: {
      user: {
        email: "ana.nova@example.com",
        current_password: "senha-segura",
        password: "",
        password_confirmation: ""
      }
    }

    expect(response).to redirect_to(account_path)
    expect(user.reload.email).to eq("ana.nova@example.com")
  end

  it "rejeita senha atual incorreta com 422 e preserva os dados" do
    user = create(:user, email: "ana@example.com", password: "senha-segura")
    sign_in_as user

    patch account_path, params: {
      user: {
        email: "outra@example.com",
        current_password: "incorreta",
        password: "nova-senha",
        password_confirmation: "nova-senha"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Senha atual")
    expect(user.reload.email).to eq("ana@example.com")
    expect(user.valid_password?("senha-segura")).to be(true)
  end

  it "bloqueia no backend alterações das credenciais de uma conta demo" do
    user = create(:user, :demo_account, email: "ana-demo-#{SecureRandom.hex(4)}@example.com", password: "senha-publica")
    sign_in_as user

    patch account_path, params: {
      user: {
        email: "ana.nova@example.com",
        current_password: "senha-publica",
        password: "nova-senha",
        password_confirmation: "nova-senha"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("As credenciais desta conta demo são públicas e não podem ser alteradas.")
    expect(user.reload.email).to eq(user.email)
    expect(user.valid_password?("senha-publica")).to be(true)
  end

  it "bloqueia a rota Devise de atualização para uma conta demo" do
    user = create(:user, :demo_account, email: "ana-demo-#{SecureRandom.hex(4)}@example.com", password: "senha-publica")
    sign_in_as user

    patch user_registration_path, params: {
      user: {
        email: "ana.nova@example.com",
        current_password: "senha-publica",
        password: "nova-senha",
        password_confirmation: "nova-senha"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.email).to eq(user.email)
    expect(user.valid_password?("senha-publica")).to be(true)
    expect(user.valid_password?("nova-senha")).to be(false)
  end

  it "mantém a atualização Devise disponível para conta não-demo" do
    user = create(:user, email: "bia-#{SecureRandom.hex(4)}@example.com", password: "senha-segura")
    sign_in_as user

    patch user_registration_path, params: {
      user: {
        email: "bia.nova@example.com",
        current_password: "senha-segura",
        password: "",
        password_confirmation: ""
      }
    }

    expect(response).to have_http_status(:found)
    expect(user.reload.email).to eq("bia.nova@example.com")
  end

  it "apresenta as credenciais demo como imutáveis sem formulário de edição" do
    user = create(:user, :demo_account, email: "ana-demo-#{SecureRandom.hex(4)}@example.com")
    sign_in_as user

    get account_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("As credenciais desta conta demo são públicas e não podem ser alteradas.")
    expect(Nokogiri::HTML(response.body).at_css("form.account-form")).to be_nil
  end
end

require "rails_helper"

RSpec.describe "Páginas de autenticação" do
  it "apresenta entrada localizada" do
    get new_user_session_path

    expect(response.body).to include("Entrar no Quitando")
    expect(response.body).to include("E-mail")
    expect(response.body).to include("Senha")
    expect(response.body).to include("Esqueci minha senha")
  end

  it "apresenta cadastro localizado" do
    get new_user_registration_path

    expect(response.body).to include("Criar sua conta")
    expect(response.body).to include("Confirme a senha")
    expect(response.body).not_to match(/cancel my account|excluir conta/i)
  end

  it "apresenta recuperação de senha localizada" do
    get new_user_password_path

    expect(response.body).to include("Recuperar senha")
    expect(response.body).to include("Enviar instruções")
  end
end

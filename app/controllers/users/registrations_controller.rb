class Users::RegistrationsController < Devise::RegistrationsController
  def update
    return super unless current_user&.demo_account?

    render_demo_account_immutable
  end

  def destroy
    return super unless current_user&.demo_account?

    render_demo_account_immutable
  end

  private

  def render_demo_account_immutable
    render plain: "As credenciais da conta demo não podem ser alteradas.", status: :unprocessable_content
  end
end

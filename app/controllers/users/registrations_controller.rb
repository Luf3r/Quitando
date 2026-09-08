class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters, only: %i[create update]

  def update
    return super unless current_user&.demo_account?

    render_demo_account_immutable
  end

  def destroy
    return super unless current_user&.demo_account?

    render_demo_account_immutable
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
  end

  def render_demo_account_immutable
    render plain: "As credenciais da conta demo não podem ser alteradas.", status: :unprocessable_content
  end
end

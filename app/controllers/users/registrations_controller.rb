class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters, only: %i[create update]

  def new
      return redirect_to demo_main_registration_url, allow_other_host: true if demo_mode?

    super
  end

  def create
    return head :forbidden if demo_mode?

    super
  end

  def update
    return super unless current_user&.demo_account?

    render_demo_account_immutable
  end

  def destroy
    return super unless current_user&.demo_account?

    render_demo_account_immutable
  end

  private

  def demo_mode?
    LocalEnvironment.demo?
  end

  def demo_main_registration_url
    main_url = ENV["QUITANDO_MAIN_URL"]
    return root_path if main_url.blank?

    URI.join(main_url, new_user_registration_path).to_s
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
  end

  def render_demo_account_immutable
    render plain: "As credenciais da conta demo não podem ser alteradas.", status: :unprocessable_content
  end
end

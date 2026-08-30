class Users::PasswordsController < Devise::PasswordsController
  def create
    return super unless demo_account_email?

    self.resource = resource_class.new
    render :new
  end

  def update
    return super unless demo_account_reset_token?

    self.resource = resource_class.new
    resource.errors.add(:reset_password_token, :invalid)
    render :edit, status: :unprocessable_content
  end

  private

  def demo_account_email?
    resource_class.where(email: normalized_password_email).pick(:demo_account) == true
  end

  def password_email
    params.dig(resource_name, :email).to_s
  end

  def normalized_password_email
    Devise::ParameterFilter
      .new(resource_class.case_insensitive_keys, resource_class.strip_whitespace_keys)
      .filter(email: password_email)
      .fetch(:email)
  end

  def demo_account_reset_token?
    resource_class.with_reset_password_token(resource_params[:reset_password_token])&.demo_account?
  end
end

class Users::PasswordsController < Devise::PasswordsController
  def create
    return super unless demo_account_email?

    self.resource = generic_password_reset_resource
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

  def generic_password_reset_resource
    resource_class.new(normalized_password_reset_attributes).tap do |record|
      resource_class.reset_password_keys.each { |key| record.errors.add(key, :not_found) }
    end
  end

  def normalized_password_reset_attributes
    attributes = resource_class.reset_password_keys.to_h { |key| [ key, resource_params[key] ] }

    Devise::ParameterFilter
      .new(resource_class.case_insensitive_keys, resource_class.strip_whitespace_keys)
      .filter(attributes)
  end

  def demo_account_reset_token?
    resource_class.with_reset_password_token(resource_params[:reset_password_token])&.demo_account?
  end
end

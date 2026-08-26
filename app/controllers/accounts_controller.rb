class AccountsController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update_with_password(account_params)
      bypass_sign_in(@user)
      redirect_to account_path, notice: "Dados da conta atualizados."
    else
      @user.password = @user.password_confirmation = nil
      render :show, status: :unprocessable_content
    end
  end

  private

  def account_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password)
  end
end

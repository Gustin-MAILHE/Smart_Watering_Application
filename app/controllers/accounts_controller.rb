class AccountsController < ApplicationController
  DEFAULT_USERS = [
    { "id" => 1, "name" => "Utilisateur 1", "password" => "motdepasse1", "role" => "admin" },
    { "id" => 2, "name" => "Utilisateur 2", "password" => "motdepasse2", "role" => "user" },
    { "id" => 3, "name" => "Utilisateur 3", "password" => "motdepasse3", "role" => "user" }
  ].freeze

  before_action :load_users

  def index
  end

  def update
    user = find_user
    return redirect_to accounts_path, alert: "Compte introuvable." if user.nil?

    if params[:password].present?
      if params[:password].length < 6
        return redirect_to accounts_path, alert: "Le mot de passe doit contenir au moins 6 caractères."
      end
      user["password"] = params[:password]
      message = "Mot de passe de #{user['name']} modifié."
    elsif %w[user admin].include?(params[:role])
      user["role"] = params[:role]
      message = "Rôle de #{user['name']} mis à jour."
    else
      return redirect_to accounts_path, alert: "Aucune modification."
    end

    save_users
    redirect_to accounts_path, notice: message
  end

  def destroy
    user = find_user
    return redirect_to accounts_path, alert: "Compte introuvable." if user.nil?

    @users.delete(user)
    save_users
    redirect_to accounts_path, notice: "Compte de #{user['name']} supprimé."
  end

  private

  def load_users
    @users = session[:users] || DEFAULT_USERS.map(&:dup)
  end

  def save_users
    session[:users] = @users
  end

  def find_user
    @users.find { |user| user["id"] == params[:id].to_i }
  end
end

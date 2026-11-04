# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action :authenticate_user!
  def index
  end
end

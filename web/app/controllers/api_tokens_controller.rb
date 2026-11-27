class ApiTokensController < ApplicationController
  def create
    days = case params[:expires].to_s
           when "30" then 30
           when "365" then 365
           when "never" then nil
           else 90
           end
    token = ApiToken.issue(user: current_user, name: params[:name].to_s.strip, expires_in_days: days)
    if token.persisted?
      flash[:new_token] = { "name" => token.name, "value" => token.raw_token, "expires" => token.expires_at&.iso8601, "scope" => token.scope }
      redirect_to account_path
    else
      redirect_to account_path, alert: token.errors.full_messages.to_sentence
    end
  end

  def destroy
    token = current_user.api_tokens.find(params[:id])
    token.expired? || token.revoked? ? token.destroy : token.revoke!
    redirect_to account_path, notice: "Token “#{token.name}” is no longer valid."
  end
end

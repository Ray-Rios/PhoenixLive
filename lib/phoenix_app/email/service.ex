defmodule PhoenixApp.Email.Service do
  @moduledoc """
  Email service for sending transactional emails via Swoosh.
  """

  require Logger
  alias PhoenixApp.Mailer
  alias PhoenixApp.Emails

  def send_verification_email(user, verification_code) do
    Logger.info("Sending verification email to #{user.email} with code: #{verification_code}")
    
    email = Emails.verification_email(user, verification_code)
    
    case Mailer.deliver(email) do
      {:ok, _metadata} ->
        Logger.info("Verification email sent successfully to #{user.email}")
        {:ok, "Verification email sent"}
      {:error, reason} ->
        Logger.error("Failed to send verification email to #{user.email}: #{inspect(reason)}")
        {:error, "Failed to send email"}
    end
  end

  def send_password_reset_email(user, reset_token) do
    reset_url = get_password_reset_url(reset_token)
    Logger.info("Sending password reset email to #{user.email}")
    
    email = Emails.password_reset_email(user, reset_url)
    
    case Mailer.deliver(email) do
      {:ok, _metadata} ->
        Logger.info("Password reset email sent successfully to #{user.email}")
        {:ok, "Password reset email sent"}
      {:error, reason} ->
        Logger.error("Failed to send password reset email to #{user.email}: #{inspect(reason)}")
        {:error, "Failed to send email"}
    end
  end

  # Helper to build password reset URL
  defp get_password_reset_url(token) do
    base_url = case get_env() do
      "prod" ->
        url_config = Application.get_env(:phoenix_app, PhoenixAppWeb.Endpoint)[:url]
        scheme = url_config[:scheme] || "https"
        host = url_config[:host] || "your-domain.com"
        port = url_config[:port]
        
        if port && port != 443 && port != 80 do
          "#{scheme}://#{host}:#{port}"
        else
          "#{scheme}://#{host}"
        end
      _ ->
        host = Application.get_env(:phoenix_app, PhoenixAppWeb.Endpoint)[:url][:host] || "localhost"
        port = Application.get_env(:phoenix_app, PhoenixAppWeb.Endpoint)[:http][:port] || 4000
        "http://#{host}:#{port}"
    end
    
    "#{base_url}/reset-password?token=#{token}"
  end

  defp get_env do
    System.get_env("MIX_ENV") || "dev"
  end
end

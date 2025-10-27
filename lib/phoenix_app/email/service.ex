defmodule PhoenixApp.Email.Service do
  @moduledoc """
  Email service for sending transactional emails via SendGrid.
  """

  require Logger

  # Helper functions to get email configuration at runtime
  defp get_from_email, do: System.get_env("FROM_EMAIL") || "no-reply@phxlive.net"
  defp get_from_name, do: System.get_env("FROM_NAME") || "PhxLive"

  def send_verification_email(user, verification_code) do
    subject = "Verify your PhxLive account"
    
    template_data = %{
      user_name: user.name,
      verification_code: verification_code,
      expiry_hours: 24
    }

    case get_env() do
      "prod" ->
        send_via_sendgrid(user.email, subject, template_data, :verification)
      _ ->
        send_via_dev(user.email, subject, template_data, :verification)
    end
  end

  def send_password_reset_email(user, reset_token) do
    subject = "Reset your PhxLive password"
    
    template_data = %{
      user_name: user.name,
      reset_url: get_password_reset_url(reset_token),
      expiry_hours: 1
    }

    case get_env() do
      "prod" ->
        send_via_sendgrid(user.email, subject, template_data, :password_reset)
      _ ->
        send_via_dev(user.email, subject, template_data, :password_reset)
    end
  end

  # Production SendGrid integration
  defp send_via_sendgrid(to_email, subject, template_data, template_type) do
    api_key = get_sendgrid_api_key()
    
    if is_nil(api_key) do
      Logger.error("SendGrid API key not configured")
      {:error, "Email service not configured"}
    else
      case template_type do
        :verification ->
          send_verification_via_sendgrid(to_email, subject, template_data, api_key)
        :password_reset ->
          send_password_reset_via_sendgrid(to_email, subject, template_data, api_key)
      end
    end
  end

  defp send_verification_via_sendgrid(to_email, subject, %{user_name: name, verification_code: code, expiry_hours: hours}, api_key) do
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>Verify Your Account</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #3B82F6; color: white; padding: 20px; text-align: center; }
            .content { padding: 30px 20px; background: #f9f9f9; }
            .code { font-size: 32px; font-weight: bold; color: #3B82F6; text-align: center; 
                    background: white; padding: 20px; border-radius: 8px; margin: 20px 0; 
                    border: 2px solid #3B82F6; letter-spacing: 4px; }
            .footer { padding: 20px; text-align: center; color: #666; font-size: 14px; }
            .rainbow-text {
                background: linear-gradient(45deg, #ff0000, #ff8c00, #ffd700, #00ff00, #0080ff, #8000ff, #ff0080);
                background-size: 200% 200%;
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                background-clip: text;
                animation: rainbow-animation 3s ease-in-out infinite;
            }
            @keyframes rainbow-animation {
                0% { background-position: 0% 50%; }
                50% { background-position: 100% 50%; }
                100% { background-position: 0% 50%; }
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Welcome to Phx<span class="rainbow-text">Live</span>!</h1>
            </div>
            <div class="content">
                <p>Hi #{name},</p>
                <p>Thank you for creating your account. Please verify your email address by entering this verification code:</p>
                <div class="code">#{code}</div>
                <p>This code will expire in #{hours} hours.</p>
                <p>If you didn't create an account, you can safely ignore this email.</p>
            </div>
            <div class="footer">
                <p>Phx<span class="rainbow-text">Live</span> | Powering your gaming experience</p>
            </div>
        </div>
    </body>
    </html>
    """

    text_content = """
    Hi #{name},

    Thank you for creating your PhxLive account.

    Please verify your email address by entering this verification code:

    #{code}

    This code will expire in #{hours} hours.

    If you didn't create an account, you can safely ignore this email.

    --
    PhxLive
    """

    send_email_request(to_email, subject, text_content, html_content, api_key)
  end

  defp send_password_reset_via_sendgrid(to_email, subject, %{user_name: name, reset_url: url, expiry_hours: hours}, api_key) do
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>Reset Your Password</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #DC2626; color: white; padding: 20px; text-align: center; }
            .content { padding: 30px 20px; background: #f9f9f9; }
            .button { display: inline-block; background: #DC2626; color: white; padding: 12px 24px; 
                     text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .footer { padding: 20px; text-align: center; color: #666; font-size: 14px; }
            .rainbow-text {
                background: linear-gradient(45deg, #ff0000, #ff8c00, #ffd700, #00ff00, #0080ff, #8000ff, #ff0080);
                background-size: 200% 200%;
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                background-clip: text;
                animation: rainbow-animation 3s ease-in-out infinite;
            }
            @keyframes rainbow-animation {
                0% { background-position: 0% 50%; }
                50% { background-position: 100% 50%; }
                100% { background-position: 0% 50%; }
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Password Reset Request</h1>
            </div>
            <div class="content">
                <p>Hi #{name},</p>
                <p>We received a request to reset your password for your PhxLive account.</p>
                <p>Click the button below to reset your password:</p>
                <p style="text-align: center;">
                    <a href="#{url}" class="button">Reset Password</a>
                </p>
                <p>This link will expire in #{hours} hour(s).</p>
                <p>If you didn't request a password reset, you can safely ignore this email.</p>
            </div>
            <div class="footer">
                <p>Phx<span class="rainbow-text">Live</span> | Powering your gaming experience</p>
            </div>
        </div>
    </body>
    </html>
    """

    text_content = """
    Hi #{name},

    We received a request to reset your password for your PhxLive account.

    Click this link to reset your password:
    #{url}

    This link will expire in #{hours} hour(s).

    If you didn't request a password reset, you can safely ignore this email.

    --
    PhxLive
    """

    send_email_request(to_email, subject, text_content, html_content, api_key)
  end

  defp send_email_request(to_email, subject, text_content, html_content, api_key) do
    url = "https://api.sendgrid.com/v3/mail/send"
    
    from_email = get_from_email()
    from_name = get_from_name()
    
    Logger.info("Sending email from: #{from_email} (#{from_name})")
    
    payload = %{
      "personalizations" => [
        %{
          "to" => [%{"email" => to_email}],
          "subject" => subject
        }
      ],
      "from" => %{
        "email" => from_email,
        "name" => from_name
      },
      "content" => [
        %{
          "type" => "text/plain",
          "value" => text_content
        },
        %{
          "type" => "text/html",
          "value" => html_content
        }
      ]
    }

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.post(url, Jason.encode!(payload), headers) do
      {:ok, %HTTPoison.Response{status_code: 202}} ->
        Logger.info("Email sent successfully to #{to_email}")
        {:ok, "Email sent successfully"}
      
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("SendGrid API error #{status_code}: #{body}")
        {:error, "Failed to send email: #{status_code}"}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{reason}")
        {:error, "Email service unavailable"}
    end
  end

  # Development email handling
  # Development email sending (using Swoosh + Mailhog)
  defp send_via_dev(to_email, subject, template_data, template_type) do
    import Swoosh.Email
    alias PhoenixApp.Mailer
    
    from_email = get_from_email()
    from_name = get_from_name()
    
    # Create email based on template type
    email = case template_type do
      :verification ->
        %{verification_code: code} = template_data
        new()
        |> to(to_email)
        |> from({from_name, from_email})
        |> subject(subject)
        |> html_body(verification_html_dev(template_data))
        |> text_body("Your verification code is: #{code}")
        
      :password_reset ->
        %{reset_url: url} = template_data
        new()
        |> to(to_email)
        |> from({from_name, from_email})
        |> subject(subject)
        |> html_body(password_reset_html_dev(template_data))
        |> text_body("Reset your password at: #{url}")
    end
    
    # Send via Swoosh (to Mailhog in development)
    case Mailer.deliver(email) do
      {:ok, _} -> 
        # Also log to console for debugging
        case template_type do
          :verification ->
            %{verification_code: code} = template_data
            IO.puts("""
            
            📧 DEV EMAIL VERIFICATION (sent to Mailhog)
            =============================================
            To: #{to_email}
            Subject: #{subject}
            
            Your verification code is: #{code}
            
            ✓ Email sent to Mailhog at: http://localhost:8025
            =============================================
            """)
            
          :password_reset ->
            %{reset_url: url} = template_data
            IO.puts("""
            
            📧 DEV PASSWORD RESET (sent to Mailhog)
            =======================================
            To: #{to_email}
            Subject: #{subject}
            
            Reset your password at: #{url}
            
            ✓ Email sent to Mailhog at: http://localhost:8025
            =======================================
            """)
        end
        
        {:ok, "Development email sent to Mailhog"}
        
      {:error, reason} ->
        Logger.error("Failed to send development email: #{inspect(reason)}")
        # Fall back to console logging
        case template_type do
          :verification ->
            %{verification_code: code} = template_data
            IO.puts("""
            
            📧 DEV EMAIL VERIFICATION (Mailhog failed, console only)
            ========================================================
            To: #{to_email}
            Subject: #{subject}
            
            Your verification code is: #{code}
            
            ⚠️ Could not send to Mailhog, check if it's running
            ========================================================
            """)
            
          :password_reset ->
            %{reset_url: url} = template_data
            IO.puts("""
            
            📧 DEV PASSWORD RESET (Mailhog failed, console only)
            ====================================================
            To: #{to_email}
            Subject: #{subject}
            
            Reset your password at: #{url}
            
            ⚠️ Could not send to Mailhog, check if it's running
            ====================================================
            """)
        end
        
        {:ok, "Development email logged to console (Mailhog unavailable)"}
    end
  end

  # HTML templates for development emails
  defp verification_html_dev(%{user_name: name, verification_code: code}) do
    """
    <h2>Welcome to PhxLive!</h2>
    <p>Hi #{name},</p>
    <p>Your verification code is: <strong style="font-size: 24px; color: #3B82F6;">#{code}</strong></p>
    <p>This code expires in 24 hours.</p>
    """
  end

  defp password_reset_html_dev(%{user_name: name, reset_url: url}) do
    """
    <h2>Reset Your Password</h2>
    <p>Hi #{name},</p>
    <p>Click the link below to reset your password:</p>
    <p><a href="#{url}" style="background: #3B82F6; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px;">Reset Password</a></p>
    <p>This link expires in 1 hour.</p>
    <p>If the button doesn't work, copy and paste this URL: #{url}</p>
    """
  end

  defp get_sendgrid_api_key do
    System.get_env("SENDGRID_API_KEY") || 
    Application.get_env(:phoenix_app, :sendgrid_api_key)
  end

  defp get_password_reset_url(token) do
    base_url = get_base_url()
    "#{base_url}/reset-password?token=#{token}"
  end

  defp get_base_url do
    case get_env() do
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
  end

  defp get_env do
    System.get_env("MIX_ENV") || "dev"
  end
end
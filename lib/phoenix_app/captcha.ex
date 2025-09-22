defmodule PhoenixApp.Captcha do
  @moduledoc """
  hCaptcha verification module.
  Handles server-side verification of CAPTCHA tokens.
  """

  require Logger

  @hcaptcha_verify_url "https://hcaptcha.com/siteverify"

  @doc """
  Verifies an hCaptcha token with hCaptcha service.
  
  ## Parameters
  - token: The response token from the frontend CAPTCHA widget
  - remote_ip: The IP address of the user (optional but recommended)
  
  ## Returns
  - {:ok, response} on successful verification
  - {:error, reason} on failure
  """
  def verify_hcaptcha(token, remote_ip \\ nil) do
    secret_key = get_secret_key()
    
    if is_nil(secret_key) or secret_key == "" do
      Logger.error("hCaptcha secret key not configured")
      {:error, "CAPTCHA verification unavailable"}
    else
      body = build_verification_body(token, secret_key, remote_ip)
      
      case make_verification_request(body) do
        {:ok, %{"success" => true}} = result ->
          Logger.info("CAPTCHA verification successful for IP: #{remote_ip}")
          result
        {:ok, %{"success" => false, "error-codes" => errors}} ->
          Logger.warning("CAPTCHA verification failed: #{inspect(errors)}")
          {:error, "CAPTCHA verification failed: #{format_errors(errors)}"}
        {:error, reason} ->
          Logger.error("CAPTCHA verification request failed: #{inspect(reason)}")
          {:error, "CAPTCHA verification service unavailable"}
      end
    end
  end

  @doc """
  Checks if CAPTCHA verification is enabled in the current environment.
  """
  def captcha_enabled? do
    get_secret_key() != nil and get_secret_key() != ""
  end

  # Private functions

  defp get_secret_key do
    System.get_env("HCAPTCHA_SECRET_KEY") || 
    Application.get_env(:phoenix_app, :hcaptcha_secret_key)
  end

  defp build_verification_body(token, secret_key, remote_ip) do
    base_params = [
      {"secret", secret_key},
      {"response", token}
    ]
    
    params = if remote_ip do
      [{"remoteip", remote_ip} | base_params]
    else
      base_params
    end
    
    {:form, params}
  end

  defp make_verification_request(body) do
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]
    
    case HTTPoison.post(@hcaptcha_verify_url, body, headers, recv_timeout: 5000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, "Invalid JSON response"}
        end
      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "HTTP #{status_code}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp format_errors(errors) when is_list(errors) do
    errors
    |> Enum.map(&format_single_error/1)
    |> Enum.join(", ")
  end
  
  defp format_errors(error), do: inspect(error)

  defp format_single_error("missing-input-secret"), do: "Missing secret key"
  defp format_single_error("invalid-input-secret"), do: "Invalid secret key"
  defp format_single_error("missing-input-response"), do: "Missing CAPTCHA response"
  defp format_single_error("invalid-input-response"), do: "Invalid CAPTCHA response"
  defp format_single_error("bad-request"), do: "Malformed request"
  defp format_single_error("timeout-or-duplicate"), do: "CAPTCHA timeout or already used"
  defp format_single_error("invalid-or-already-seen-response"), do: "CAPTCHA already used"
  defp format_single_error("not-using-dummy-passcode"), do: "Test CAPTCHA not accepted in production"
  defp format_single_error("sitekey-secret-mismatch"), do: "Site key and secret key mismatch"
  defp format_single_error(error), do: error
end
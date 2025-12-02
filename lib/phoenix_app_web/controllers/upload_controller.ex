defmodule PhoenixAppWeb.UploadController do
  use PhoenixAppWeb, :controller
  require Logger

  def signed_download(conn, %{"token" => token} = params) do
    expires_in = params["expires_in"] |> case do
      nil -> 3600
      s when is_binary(s) -> String.to_integer(s)
      i when is_integer(i) -> i
    end

    case Phoenix.Token.verify(PhoenixAppWeb.Endpoint, "uploads", token, max_age: expires_in) do
      {:ok, url_path} when is_binary(url_path) ->
        fs_path = PhoenixApp.Uploads.url_to_path(url_path)

        if fs_path && File.exists?(fs_path) do
          conn
          |> put_resp_header("cache-control", "public, max-age=#{min(expires_in, 3600)}")
          |> send_file(200, fs_path)
        else
          conn |> send_resp(404, "Not found")
        end

      {:error, _reason} ->
        Logger.warning("Invalid or expired upload token requested")
        conn |> send_resp(403, "Invalid or expired token")
    end
  end
end

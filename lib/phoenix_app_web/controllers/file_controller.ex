defmodule PhoenixAppWeb.FileController do
  use PhoenixAppWeb, :controller
  alias PhoenixApp.Files

  def upload(conn, %{"file" => file_params}) do
    user = conn.assigns.current_user
    
    if user do
      case Files.create_user_file(user, file_params) do
        {:ok, file} ->
          conn
          |> put_status(:created)
          |> json(%{
            id: file.id,
            filename: file.original_filename,
            size: file.file_size,
            url: PhoenixApp.UserFileUpload.url({file.file, file})
          })
        
        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: translate_errors(changeset)})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Authentication required"})
    end
  end

  def delete(conn, %{"id" => file_id}) do
    user = conn.assigns.current_user
    
    if user do
      try do
        file = Files.get_user_file!(user, file_id)
        
        case Files.delete_user_file(file) do
          {:ok, _} ->
            conn
            |> put_status(:ok)
            |> json(%{message: "File deleted successfully"})
          
          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to delete file"})
        end
      rescue
        Ecto.NoResultsError ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "File not found"})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Authentication required"})
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
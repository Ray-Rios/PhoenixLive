defmodule PhoenixApp.Files do
  @moduledoc """
  File management context
  """

  def create_user_file(_user, _file_params) do
    {:error, "File upload not implemented yet"}
  end

  def get_user_file!(_user, _file_id) do
    raise "File retrieval not implemented yet"
  end

  def delete_user_file(_file) do
    {:error, "File deletion not implemented yet"}
  end
end
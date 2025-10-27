defmodule PhoenixApp.Content.UserMedia do
  @moduledoc "Schema for user uploaded media assets"
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_media" do
    field :filename, :string
    field :original_filename, :string
    field :file_type, :string
    field :mime_type, :string
    field :file_size, :integer
    field :file_path, :string
    field :url, :string
    field :metadata, :map
    field :alt_text, :string
    field :caption, :string
    field :usage_context, :string
    field :is_public, :boolean, default: false

    belongs_to :user, PhoenixApp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @required ~w(filename original_filename file_type mime_type file_size file_path url)a

  def changeset(media, attrs) do
    media
    |> cast(attrs, [
      :filename,
      :original_filename,
      :file_type,
      :mime_type,
      :file_size,
      :file_path,
      :url,
      :metadata,
      :alt_text,
      :caption,
      :usage_context,
      :is_public,
      :user_id
    ])
    |> validate_required(@required)
    |> validate_inclusion(:file_type, ["image", "video", "audio", "3d", "document"]) 
  end
end

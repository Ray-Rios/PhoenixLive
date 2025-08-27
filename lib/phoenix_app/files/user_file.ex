defmodule PhoenixApp.Files.UserFile do
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_files" do
    field :filename, :string
    field :original_filename, :string
    field :content_type, :string
    field :file_size, :integer
    field :file_path, :string
    field :file, PhoenixApp.UserFileUpload.Type
    field :is_public, :boolean, default: false
    field :description, :string
    field :tags, {:array, :string}, default: []

    belongs_to :user, PhoenixApp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(user_file, attrs) do
    user_file
    |> cast(attrs, [:filename, :original_filename, :content_type, :file_size, :file_path, :is_public, :description, :tags])
    |> cast_attachments(attrs, [:file])
    |> validate_required([:filename, :content_type, :file_size])
    |> validate_number(:file_size, greater_than: 0)
  end

  def is_image?(%__MODULE__{content_type: content_type}) do
    String.starts_with?(content_type, "image/")
  end

  def is_video?(%__MODULE__{content_type: content_type}) do
    String.starts_with?(content_type, "video/")
  end

  def is_audio?(%__MODULE__{content_type: content_type}) do
    String.starts_with?(content_type, "audio/")
  end

  def is_document?(%__MODULE__{content_type: content_type}) do
    content_type in ["application/pdf", "application/msword", "text/plain", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"]
  end

  def format_file_size(size_bytes) when is_integer(size_bytes) do
    cond do
      size_bytes >= 1_073_741_824 -> "#{Float.round(size_bytes / 1_073_741_824, 2)} GB"
      size_bytes >= 1_048_576 -> "#{Float.round(size_bytes / 1_048_576, 2)} MB"
      size_bytes >= 1024 -> "#{Float.round(size_bytes / 1024, 2)} KB"
      true -> "#{size_bytes} B"
    end
  end

  def format_file_size(_), do: "0 B"
end
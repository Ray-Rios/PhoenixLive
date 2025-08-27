defmodule PhoenixApp.Chat.MessageAttachment do
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chat_message_attachments" do
    field :filename, :string
    field :content_type, :string
    field :file_size, :integer
    field :file, PhoenixApp.ChatAttachment.Type

    belongs_to :message, PhoenixApp.Chat.Message

    timestamps(type: :utc_datetime)
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:filename, :content_type, :file_size])
    |> cast_attachments(attrs, [:file])
    |> validate_required([:filename, :content_type, :file_size])
  end
end
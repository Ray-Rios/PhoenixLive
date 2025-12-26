defmodule PhoenixApp.Commerce.DownloadToken do
  @moduledoc """
  Schema for secure digital product download tokens.
  
  When a user purchases a digital product, a unique token is generated
  that allows them to download the product a limited number of times.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "download_tokens" do
    field :token, :string
    field :download_count, :integer, default: 0
    field :max_downloads, :integer
    field :expires_at, :utc_datetime
    field :first_downloaded_at, :utc_datetime
    field :last_downloaded_at, :utc_datetime
    field :ip_address, :string

    belongs_to :user, PhoenixApp.Accounts.User
    belongs_to :product, PhoenixApp.Commerce.Product
    belongs_to :order, PhoenixApp.Commerce.Order

    timestamps(type: :utc_datetime)
  end

  @required_fields [:token, :user_id, :product_id]
  @optional_fields [:order_id, :max_downloads, :expires_at, :download_count, 
                    :first_downloaded_at, :last_downloaded_at, :ip_address]

  def changeset(token, attrs) do
    token
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:token)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:order_id)
  end

  @doc """
  Creates a new download token for a user/product combination.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(Map.merge(attrs, %{
      token: generate_token(),
      download_count: 0
    }))
  end

  @doc """
  Records a download attempt, incrementing the counter.
  """
  def record_download_changeset(token, ip_address \\ nil) do
    now = DateTime.utc_now()
    
    changes = %{
      download_count: token.download_count + 1,
      last_downloaded_at: now,
      ip_address: ip_address
    }
    
    # Set first_downloaded_at only on first download
    changes = if is_nil(token.first_downloaded_at) do
      Map.put(changes, :first_downloaded_at, now)
    else
      changes
    end
    
    changeset(token, changes)
  end

  @doc """
  Checks if the token is still valid for downloading.
  """
  def valid?(token) do
    not expired?(token) and not download_limit_reached?(token)
  end

  @doc """
  Checks if the token has expired.
  """
  def expired?(%{expires_at: nil}), do: false
  def expired?(%{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Checks if the download limit has been reached.
  """
  def download_limit_reached?(%{max_downloads: nil}), do: false
  def download_limit_reached?(%{max_downloads: max, download_count: count}) do
    count >= max
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end
end

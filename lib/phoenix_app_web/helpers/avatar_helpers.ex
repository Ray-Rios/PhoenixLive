defmodule PhoenixAppWeb.AvatarHelpers do
  @moduledoc """
  Helpers for displaying user avatars with proper precedence:
  1. Custom uploaded avatar (highest priority)
  2. Generated color/shape avatar  
  3. Default avatar image (fallback)
  """
  
  use Phoenix.Component

  @doc """
  Returns the avatar HTML for a user.
  
  Precedence:
  1. If user.avatar_url is set -> show uploaded image
  2. Else if user.avatar_color is set -> show generated avatar with first letter
  3. Else -> show default avatar image
  """
  def avatar_tag(user, opts \\ []) do
    size_class = Keyword.get(opts, :size_class, "w-10 h-10")
    shape = user.avatar_shape || "circle"
    color = user.avatar_color || "#3B82F6"
    
    shape_classes = case shape do
      "circle" -> "rounded-full"
      "square" -> "rounded-none"
      "rounded" -> "rounded-lg"
      _ -> "rounded-full"
    end

    assigns = %{
      user: user,
      size_class: size_class,
      shape_classes: shape_classes,
      color: color,
      initial: get_user_initial(user)
    }

    cond do
      # Priority 1: Custom uploaded avatar
      user.avatar_url && String.trim(user.avatar_url) != "" ->
        ~H"""
        <img src={@user.avatar_url} alt={@user.name || "Avatar"} class={"#{@size_class} object-cover border-2 #{@shape_classes}"} style={"border-color: #{@color}"} />
        """

      # Priority 2: Generated color/shape avatar
      user.avatar_color || user.avatar_shape ->
        ~H"""
        <div class={"#{@size_class} flex items-center justify-center text-white font-bold #{@shape_classes} border-2"} style={"background-color: #{@color}; border-color: #{@color}"}>
          <%= @initial %>
        </div>
        """

      # Priority 3: Default avatar image
      true ->
        ~H"""
        <img src="/uploads/public/images/default_avatar.jpg" alt="Default Avatar" class={"#{@size_class} object-cover #{@shape_classes}"} />
        """
    end
  end

  @doc """
  Gets the user's initial for generated avatars.
  """
  def get_user_initial(user) do
    cond do
      user.name && String.trim(user.name) != "" ->
        user.name |> String.first() |> String.upcase()
      user.email && String.trim(user.email) != "" ->
        user.email |> String.first() |> String.upcase()
      true ->
        "?"
    end
  end

  @doc """
  Returns just the avatar URL string (for APIs or direct URL access).
  """
  def avatar_url(user) do
    cond do
      user.avatar_url && String.trim(user.avatar_url) != "" ->
        user.avatar_url
      true ->
        "/uploads/public/images/default_avatar.jpg"
    end
  end

  @doc """
  Checks if user has a custom uploaded avatar.
  """
  def has_custom_avatar?(user) do
    user.avatar_url && String.trim(user.avatar_url) != ""
  end
end

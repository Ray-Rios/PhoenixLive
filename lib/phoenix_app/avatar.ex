defmodule PhoenixApp.Avatar do
  use Arc.Definition
  use Arc.Ecto.Definition

  @versions [:original, :thumb]
  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()
    Enum.member?(@extension_whitelist, file_extension)
  end

  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 100x100^ -gravity center -extent 100x100 -format png", :png}
  end

  def filename(version, {_file, scope}) do
    "#{scope.id}_#{version}"
  end

  def storage_dir(_version, {_file, scope}) do
    "uploads/avatars/#{scope.id}"
  end

  def default_url(:thumb) do
    "/images/default_avatar.png"
  end

  def default_url(_version) do
    "/images/default_avatar.png"
  end
end
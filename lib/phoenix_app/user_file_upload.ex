defmodule PhoenixApp.UserFileUpload do
  use Arc.Definition
  use Arc.Ecto.Definition

  @versions [:original, :thumb]

  # Validate file types - allow common file types
  def validate({_file, _}) do
    # Allow most common file types
    true
  end

  # Generate thumbnail for image files
  def transform(:thumb, {file, _scope}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()
    
    if file_extension in [".jpg", ".jpeg", ".png", ".gif", ".webp"] do
      {:convert, "-strip -thumbnail 200x200^ -gravity center -extent 200x200 -format png", :png}
    else
      :noaction
    end
  end

  def filename(version, {file, scope}) do
    file_name = Path.basename(file.file_name, Path.extname(file.file_name))
    "#{scope.id}_#{file_name}_#{version}"
  end

  def storage_dir(_version, {_file, scope}) do
    "uploads/user_files/#{scope.user_id}"
  end

  def default_url(:thumb) do
    "/images/default_file.png"
  end

  def default_url(_version) do
    nil
  end
end

defmodule PhoenixApp.UserFileUpload do
  use Arc.Definition
  use Arc.Ecto.Definition

  @versions [:original]

  def validate({file, _}) do
    # Allow most common file types, restrict dangerous ones
    file_extension = file.file_name |> Path.extname() |> String.downcase()
    
    allowed_extensions = ~w(.jpg .jpeg .gif .png .webp .pdf .doc .docx .txt .mp3 .mp4 .avi .mov .zip .rar)
    dangerous_extensions = ~w(.exe .bat .cmd .scr .pif .com .vbs .js .jar .app .deb .rpm)
    
    Enum.member?(allowed_extensions, file_extension) and not Enum.member?(dangerous_extensions, file_extension)
  end

  def filename(version, {file, scope}) do
    name = Path.basename(file.file_name, Path.extname(file.file_name))
    "#{scope.id}_#{name}_#{version}#{Path.extname(file.file_name)}"
  end

  def storage_dir(_version, {_file, scope}) do
    "uploads/user_files/#{scope.id}"
  end
end
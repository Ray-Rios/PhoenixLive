defmodule PhoenixAppWeb.PageController do
  use PhoenixAppWeb, :controller

  @levels_dir Path.join([:code.priv_dir(:phoenix_app), "static/levels"])

  ## Index (normal Phoenix homepage)
  def index(conn, _params) do
    render(conn, :index)
  end

  ## --- ImpactJS Weltmeister Editor ---

  # Serve the Weltmeister HTML editor
  def weltmeister(conn, _params) do
    file_path =
      :phoenix_app
      |> :code.priv_dir()
      |> Path.join("static/impact/weltmeister.html")

    if File.exists?(file_path) do
      conn
      |> put_resp_content_type("text/html")
      |> send_file(200, file_path)
    else
      send_resp(conn, 404, "Weltmeister editor not found")
    end
  end

  ## --- Level management ---

  # GET /admin/levels
  # List all available level files
  def list_levels(conn, _params) do
    File.mkdir_p!(@levels_dir)

    levels =
      @levels_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.map(&Path.rootname/1)

    json(conn, %{levels: levels})
  end

  # GET /admin/levels/:name
  # Return JSON of a specific level
  def get_level(conn, %{"name" => name}) do
    file = Path.join(@levels_dir, "#{name}.json")

    case File.read(file) do
      {:ok, data} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, data)

      {:error, _} ->
        send_resp(conn, 404, "Level not found")
    end
  end

  # POST or PUT /admin/levels/:name
  # Save JSON data from Weltmeister
  def save_level(conn, %{"name" => name} = params) do
    File.mkdir_p!(@levels_dir)

    file = Path.join(@levels_dir, "#{name}.json")

    case Map.fetch(params, "data") do
      {:ok, json_data} ->
        File.write!(file, json_data)

        json(conn, %{status: "ok", level: name})

      :error ->
        send_resp(conn, 400, "Missing 'data' param")
    end
  end
end

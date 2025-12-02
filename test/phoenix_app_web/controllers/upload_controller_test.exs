defmodule PhoenixAppWeb.UploadControllerTest do
  use Phoenix.ConnTest, async: true
  alias PhoenixApp.Uploads
  alias PhoenixApp.Accounts

  @endpoint PhoenixAppWeb.Endpoint

  test "signed URL allows access to local upload" do
    {:ok, user} = Accounts.create_user(%{email: "u-signed@example.com", name: "signed", password: "Test@1234"})

    # Ensure directory exists and create a small file
    dir = Uploads.user_dir(user.id, context: "tests")
    :ok = File.mkdir_p(dir)
    filename = "test-file.txt"
    file_path = Path.join(dir, filename)
    File.write!(file_path, "hello-signed")

    url_path = Uploads.url_path(user.id, "tests", filename)
    signed = Uploads.signed_url_for(url_path, expires_in: 60)

    # Extract token query param
    %URI{query: query} = URI.parse(signed)
    token = URI.decode_query(query)["token"]

    conn = build_conn()
    conn = get(conn, "/uploads/signed?token=#{token}&expires_in=60")

    assert conn.status == 200
    assert conn.resp_body == "hello-signed"
  end
end

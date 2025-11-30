defmodule PhoenixAppWeb.Api.ApiAuthControllerTest do
  use PhoenixAppWeb.ConnCase, async: true
  alias PhoenixApp.{Accounts, Repo}

  describe "POST /api/auth/register" do
    test "creates user with valid credentials", %{conn: conn} do
      params = %{
        "email" => "test#{System.unique_integer([:positive])}@example.com",
        "password" => "SecurePass123!",
        "name" => "Test User"
      }

      conn = post(conn, ~p"/api/auth/register", params)

      assert %{
               "success" => true,
               "message" => "Account created successfully",
               "token" => token,
               "user" => user
             } = json_response(conn, 201)

      assert is_binary(token)
      assert user["email"] == params["email"]
      assert user["name"] == params["name"]
    end

    test "returns error with invalid email", %{conn: conn} do
      params = %{
        "email" => "invalid-email",
        "password" => "SecurePass123!",
        "name" => "Test User"
      }

      conn = post(conn, ~p"/api/auth/register", params)

      assert %{"success" => false, "errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "email")
    end

    test "returns conflict when email already exists", %{conn: conn} do
      email = "duplicate#{System.unique_integer([:positive])}@example.com"
      
      {:ok, _user} = Accounts.create_user(%{
        email: email,
        name: "First User",
        password: "Pass123!"
      })

      params = %{"email" => email, "password" => "Pass123!", "name" => "Second User"}
      conn = post(conn, ~p"/api/auth/register", params)

      assert %{"success" => false} = json_response(conn, 409)
    end
  end

  describe "POST /api/auth/login" do
    setup do
      # Create a verified user for login tests
      {:ok, user} = Accounts.create_user(%{
        email: "login#{System.unique_integer([:positive])}@example.com",
        name: "Login Test",
        password: "Test@1234"
      })
      
      # Verify the user so they can log in
      {:ok, user} = Accounts.verify_user_email_direct(user)

      %{user: user, password: "Test@1234"}
    end

    test "logs in with valid credentials", %{conn: conn, user: user, password: password} do
      params = %{"email" => user.email, "password" => password}
      conn = post(conn, ~p"/api/auth/login", params)

      assert %{
               "success" => true,
               "message" => "Login successful",
               "token" => token,
               "user" => returned_user
             } = json_response(conn, 200)

      assert is_binary(token)
      assert returned_user["id"] == user.id
      assert returned_user["email"] == user.email
      assert get_session(conn, :user_id) == user.id
    end

    test "returns error with invalid password", %{conn: conn, user: user} do
      params = %{"email" => user.email, "password" => "WrongPassword123!"}
      conn = post(conn, ~p"/api/auth/login", params)

      assert %{"success" => false, "error" => _msg} = json_response(conn, 401)
      refute get_session(conn, :user_id)
    end

    test "returns error for non-existent user", %{conn: conn} do
      params = %{"email" => "nonexistent@example.com", "password" => "Pass123!"}
      conn = post(conn, ~p"/api/auth/login", params)

      assert %{"success" => false} = json_response(conn, 401)
    end
  end
end

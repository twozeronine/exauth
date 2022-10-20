defmodule ExauthWeb.AuthController do
  use ExauthWeb, :controller
  import Plug.Conn
  alias Exauth.Repo
  alias Exauth.Accounts
  alias Exauth.Accounts.User
  alias ExauthWeb.JWTToken
  alias Exauth.AuthTokens.AuthToken

  def ping(conn, _params) do
    conn
    |> render("ack.json", %{success: true, message: "Pong"})
  end

  def register(conn, params) do
    case Accounts.create_user(params) do
      {:ok, _user} ->
        conn |> render("ack.json", %{success: true, message: "Reistration successful"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn |> render("errors.json", %{errors: format_changeset_errors(changeset)})

      _ ->
        conn |> render("error.json", %{error: "Internal Server Error"})
    end
  end

  def login(conn, %{"username" => username, "password" => password}) do
    with %User{} = user <- Accounts.get_user_by_username(username),
         true <- Pbkdf2.verify_pass(password, user.password) do
      signer =
        Joken.Signer.create(
          "HS256",
          "b6sMoh+DWiHeGTGTu5c87f3+zj7olyjZ1tsZ8jvxYEtGDq4vFTsy5cxH8VFZzj6J"
        )

      extra_claims = %{user_id: user.id}
      {:ok, token, _claims} = JWTToken.generate_and_sign(extra_claims, signer)

      conn |> render("login.json", %{success: true, message: "Login Successful", token: token})
    else
      _ -> conn |> render("error.json", %{error: "Invalid Credentials"})
    end
  end

  def get(conn, _param) do
    conn |> render("data.json", %{data: conn.assigns.current_user})
  end

  def delete(conn, _params) do
    case Ecto.build_assoc(conn.assigns.current_user, :auth_tokens, %{token: get_token(conn)})
         |> Repo.insert() do
      {:ok, %AuthToken{}} ->
        conn |> render("ack.json", %{success: true, message: "Logged Out"})

      _ ->
        conn |> render("error.json", %{error: "Internal Server Error"})
    end
  end

  defp get_token(conn) do
    bearer = get_req_header(conn, "authorization") |> List.first()

    if bearer == nil do
      ""
    else
      token = bearer |> String.split(" ") |> List.last()
    end
  end

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    formatted_errors =
      Enum.map(errors, fn {key, value} ->
        formatted_error = "#{key} #{value}"
        formatted_error
      end)

    formatted_errors
  end
end

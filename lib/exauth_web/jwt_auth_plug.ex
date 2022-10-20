defmodule ExauthWeb.JwtAuthPlug do
  import Plug.Conn

  alias Exauth.Accounts
  alias Exauth.Accounts.User

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    bearer = get_req_header(conn, "authorization") |> List.first()

    if bearer == nil do
      conn |> put_status(401) |> halt()
    else
      token = bearer |> String.split(" ") |> List.last()

      signer =
        Joken.Signer.create(
          "HS256",
          "b6sMoh+DWiHeGTGTu5c87f3+zj7olyjZ1tsZ8jvxYEtGDq4vFTsy5cxH8VFZzj6J"
        )

      with {:ok, %{"user_id" => user_id}} <-
             ExauthWeb.JWTToken.verify_and_validate(token, signer),
           %User{} = user <- Accounts.get_user(user_id) do
        IO.inspect(user)

        conn |> assign(:current_user, user)
      else
        {:error, _reason} -> conn |> put_status(401) |> halt()
        _ -> conn |> put_status(401) |> halt()
      end
    end
  end
end

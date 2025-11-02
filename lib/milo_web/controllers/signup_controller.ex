defmodule MiloWeb.SignupController do
  use MiloWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end

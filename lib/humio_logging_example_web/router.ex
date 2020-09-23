defmodule HumioLoggingExampleWeb.Router do
  use HumioLoggingExampleWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {HumioLoggingExampleWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HumioLoggingExampleWeb do
    pipe_through :browser

    get  "/", Router.Redirector, to: "/chats/talk?user=humio"
    live "/chats/:topic", PageLive
    live_dashboard "/dashboard"
  end

end

defmodule HumioLoggingExampleWeb.Router.Redirector do
  import Phoenix.Controller, only: [redirect: 2]

  def init([to: _] = opts), do: opts

  def call(conn, [to: to]) do
    redirect(conn, to: to)
  end
end

defmodule MiloWeb.Router do
  use MiloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MiloWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug MiloWeb.UserAuth, :fetch_current_user
    plug MiloWeb.UserAuth, :require_authenticated_user
  end

  scope "/", MiloWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/signup", SignupController, :index

    get "/auth/:provider", AuthController, :request
    get "/auth/:provider/callback", AuthController, :callback
  end

  scope "/", MiloWeb do
    pipe_through [:browser, :authenticated]

    get "/onboarding", OnboardingController, :index

    live "/inbox", InboxLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", MiloWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:milo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MiloWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

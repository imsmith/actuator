defmodule ActuatorWeb.Router do
  @moduledoc """
  Routes.

    * `/t/:name` (POST) and `/t/openapi.json` (GET): the listener API, bearer token
    * `/admin/*`: the admin UI, HTTP basic auth with user `admin` and the same token
    * `/dev/dashboard`: LiveDashboard in dev
  """
  use ActuatorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ActuatorWeb.Layouts, :root}
    plug :protect_from_forgery
    # 'unsafe-inline' for scripts covers the root layout's theme bootstrap; see ISSUES.md.
    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'"
    }
  end

  pipeline :admin do
    plug :admin_auth
  end

  defp admin_auth(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn,
      username: "admin",
      password: Application.fetch_env!(:actuator, :api_token)
    )
  end

  scope "/admin", ActuatorWeb do
    pipe_through [:browser, :admin]

    live "/transducers", TransducerLive.Index, :index
    live "/transducers/new", TransducerLive.Form, :new
    live "/transducers/:id", TransducerLive.Show, :show
    live "/transducers/:id/edit", TransducerLive.Form, :edit

    live "/api_specs", ApiSpecLive.Index, :index
    live "/api_specs/new", ApiSpecLive.Form, :new
    live "/api_specs/:id", ApiSpecLive.Show, :show
    live "/api_specs/:id/edit", ApiSpecLive.Form, :edit

    live "/listener", ListenerDocLive, :index
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug ActuatorWeb.Plugs.ApiAuth
  end

  scope "/t", ActuatorWeb do
    pipe_through :api

    get "/openapi.json", ListenerSpecController, :show
    post "/:name", TransducerController, :actuate
  end

  scope "/", ActuatorWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", ActuatorWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:actuator, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ActuatorWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

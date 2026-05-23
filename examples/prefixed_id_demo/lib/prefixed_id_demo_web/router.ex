defmodule PrefixedIdDemoWeb.Router do
  use PrefixedIdDemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PrefixedIdDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :graphql do
    plug AshGraphql.Plug
  end

  scope "/", PrefixedIdDemoWeb do
    pipe_through :browser

    live "/", CatalogLive, :index
  end

  scope "/gql" do
    pipe_through [:graphql]

    forward "/playground",
            Absinthe.Plug.GraphiQL,
            schema: Module.concat(["PrefixedIdDemo.GraphqlSchema"]),
            interface: :playground

    forward "/",
            Absinthe.Plug,
            schema: Module.concat(["PrefixedIdDemo.GraphqlSchema"])
  end

  scope "/api/json" do
    pipe_through :api

    forward "/catalog", PrefixedIdDemoWeb.JsonApiRouter
  end

  scope "/rpc", PrefixedIdDemoWeb do
    pipe_through :api

    post "/run", RpcController, :run
    post "/validate", RpcController, :validate
  end

  # Other scopes may use custom stacks.
  # scope "/api", PrefixedIdDemoWeb do
  #   pipe_through :api
  # end
end

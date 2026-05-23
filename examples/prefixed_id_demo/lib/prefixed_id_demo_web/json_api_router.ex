defmodule PrefixedIdDemoWeb.JsonApiRouter do
  use AshJsonApi.Router,
    domains: [PrefixedIdDemo.Catalog],
    open_api: "/open_api"
end

defmodule PrefixedIdDemo.GraphqlSchema do
  use Absinthe.Schema

  use AshGraphql,
    domains: [PrefixedIdDemo.Catalog]

  query do
  end

  mutation do
  end
end

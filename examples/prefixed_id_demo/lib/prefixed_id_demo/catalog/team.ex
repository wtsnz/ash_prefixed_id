defmodule PrefixedIdDemo.Catalog.Team do
  use Ash.Resource,
    domain: PrefixedIdDemo.Catalog,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPrefixedId,
      AshGraphql.Resource,
      AshJsonApi.Resource,
      AshTypescript.Resource
    ]

  prefixed_id do
    prefix("team")
    migration_default?(true)
  end

  graphql do
    type(:team)
  end

  json_api do
    type("team")
  end

  typescript do
    type_name("Team")
  end

  postgres do
    table("teams")
    repo(PrefixedIdDemo.Repo)
  end

  actions do
    read :read do
      primary?(true)
      public?(true)
    end

    read :get_by_id do
      public?(true)
      get_by(:id)
    end

    create :create do
      primary?(true)
      public?(true)
      accept([:name])
    end
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    timestamps public?: true
  end

  relationships do
    has_many :projects, PrefixedIdDemo.Catalog.Project do
      public?(true)
    end
  end
end

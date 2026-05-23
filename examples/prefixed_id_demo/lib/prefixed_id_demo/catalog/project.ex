defmodule PrefixedIdDemo.Catalog.Project do
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
    prefix("proj")
    migration_default?(true)
  end

  graphql do
    type(:project)
  end

  json_api do
    type("project")
  end

  typescript do
    type_name("Project")
  end

  postgres do
    table("projects")
    repo(PrefixedIdDemo.Repo)

    references do
      reference(:team, on_delete: :delete, index?: true)
    end
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
      accept([:name, :team_id])
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
    belongs_to :team, PrefixedIdDemo.Catalog.Team do
      allow_nil?(false)
      public?(true)
    end

    has_many :todos, PrefixedIdDemo.Catalog.Todo do
      public?(true)
    end
  end
end

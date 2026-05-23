defmodule PrefixedIdDemo.Catalog.Todo do
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
    prefix("todo")
    legacy_prefixes(["task"])
    migration_default?(true)
    typescript_brand?(true)
    phoenix_param?(true)
  end

  graphql do
    type(:todo)
  end

  json_api do
    type("todo")
  end

  typescript do
    type_name("Todo")
  end

  postgres do
    table("todos")
    repo(PrefixedIdDemo.Repo)

    references do
      reference(:project, on_delete: :delete, index?: true)
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
      accept([:title, :done, :project_id])
    end
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :done, :boolean do
      default(false)
      public?(true)
    end

    timestamps public?: true
  end

  relationships do
    belongs_to :project, PrefixedIdDemo.Catalog.Project do
      allow_nil?(false)
      public?(true)
    end
  end
end

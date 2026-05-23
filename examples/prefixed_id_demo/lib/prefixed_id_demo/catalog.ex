defmodule PrefixedIdDemo.Catalog do
  use Ash.Domain,
    extensions: [
      AshGraphql.Domain,
      AshJsonApi.Domain,
      AshTypescript.Rpc
    ]

  resources do
    resource(PrefixedIdDemo.Catalog.Team)
    resource(PrefixedIdDemo.Catalog.Project)
    resource(PrefixedIdDemo.Catalog.Todo)
  end

  graphql do
    queries do
      list(PrefixedIdDemo.Catalog.Team, :list_teams, :read)
      get PrefixedIdDemo.Catalog.Team, :get_team, :get_by_id

      list(PrefixedIdDemo.Catalog.Project, :list_projects, :read)
      get PrefixedIdDemo.Catalog.Project, :get_project, :get_by_id

      list(PrefixedIdDemo.Catalog.Todo, :list_todos, :read)
      get PrefixedIdDemo.Catalog.Todo, :get_todo, :get_by_id
    end

    mutations do
      create(PrefixedIdDemo.Catalog.Team, :create_team, :create)
      create(PrefixedIdDemo.Catalog.Project, :create_project, :create)
      create(PrefixedIdDemo.Catalog.Todo, :create_todo, :create)
    end
  end

  json_api do
    routes do
      base_route "/teams", PrefixedIdDemo.Catalog.Team do
        get(:read)
        index(:read)
        post(:create)
      end

      base_route "/projects", PrefixedIdDemo.Catalog.Project do
        get(:read)
        index(:read)
        post(:create)
      end

      base_route "/todos", PrefixedIdDemo.Catalog.Todo do
        get(:read)
        index(:read)
        post(:create)
      end
    end
  end

  typescript_rpc do
    resource PrefixedIdDemo.Catalog.Team do
      rpc_action(:list_teams, :read)
      rpc_action(:get_team, :get_by_id)
      rpc_action(:create_team, :create)
    end

    resource PrefixedIdDemo.Catalog.Project do
      rpc_action(:list_projects, :read)
      rpc_action(:get_project, :get_by_id)
      rpc_action(:create_project, :create)
    end

    resource PrefixedIdDemo.Catalog.Todo do
      rpc_action(:list_todos, :read)
      rpc_action(:get_todo, :get_by_id)
      rpc_action(:create_todo, :create)
    end
  end
end

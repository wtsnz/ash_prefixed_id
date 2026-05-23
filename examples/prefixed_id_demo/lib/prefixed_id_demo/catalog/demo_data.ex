defmodule PrefixedIdDemo.Catalog.DemoData do
  alias PrefixedIdDemo.Catalog.Project
  alias PrefixedIdDemo.Catalog.Team
  alias PrefixedIdDemo.Catalog.Todo

  def seed! do
    team =
      create_team!("Platform")

    project =
      create_project!(team, "Ash prefixed ID spike")

    create_todo!(project, "GraphQL reads nested prefixed IDs")
    create_todo!(project, "JSON:API creates records with prefixed foreign keys")

    team
  end

  def create_chain! do
    suffix = DateTime.utc_now() |> Calendar.strftime("%H:%M:%S")
    team = create_team!("Spike team #{suffix}")
    project = create_project!(team, "Relationship proof #{suffix}")
    todo = create_todo!(project, "Created from LiveView at #{suffix}")

    %{team: team, project: project, todo: todo}
  end

  def create_team!(name) do
    Team
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.create!()
  end

  def create_project!(team, name) do
    Project
    |> Ash.Changeset.for_create(:create, %{name: name, team_id: team.id})
    |> Ash.create!()
  end

  def create_todo!(project, title) do
    Todo
    |> Ash.Changeset.for_create(:create, %{title: title, project_id: project.id})
    |> Ash.create!()
  end
end

defmodule PrefixedIdDemoWeb.CatalogLive do
  use PrefixedIdDemoWeb, :live_view

  alias PrefixedIdDemo.Catalog
  alias PrefixedIdDemo.Catalog.DemoData
  alias PrefixedIdDemo.Catalog.Project
  alias PrefixedIdDemo.Catalog.Team
  alias PrefixedIdDemo.Catalog.Todo

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(resolver_id: "", resolver_result: nil, resolver_error: nil)
      |> assign_catalog()
      |> assign_default_resolver()

    {:ok, socket}
  end

  @impl true
  def handle_event("create_chain", _params, socket) do
    DemoData.create_chain!()

    socket =
      socket
      |> put_flash(:info, "Created a team, project, and todo through Ash actions.")
      |> assign_catalog()

    {:noreply, socket}
  end

  @impl true
  def handle_event("resolve_id", %{"resolver" => %{"id" => id}}, socket) do
    {:noreply, resolve_prefixed_id(socket, id)}
  end

  def handle_event("resolve_id", %{"id" => id}, socket) do
    {:noreply, resolve_prefixed_id(socket, id)}
  end

  defp assign_catalog(socket) do
    teams =
      Team
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.load(projects: [:todos])
      |> Ash.read!()

    projects =
      Project
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.load([:team, :todos])
      |> Ash.read!()

    todos =
      Todo
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.load(project: [:team])
      |> Ash.read!()

    assign(socket,
      teams: teams,
      projects: projects,
      todos: todos,
      domain: inspect(Catalog),
      sample_legacy_todo_id: todos |> List.first() |> legacy_todo_id()
    )
  end

  defp assign_default_resolver(%{assigns: %{sample_legacy_todo_id: nil}} = socket), do: socket

  defp assign_default_resolver(%{assigns: %{resolver_id: resolver_id}} = socket)
       when resolver_id not in [nil, ""] do
    socket
  end

  defp assign_default_resolver(%{assigns: %{sample_legacy_todo_id: id}} = socket) do
    resolve_prefixed_id(socket, id)
  end

  defp resolve_prefixed_id(socket, id) do
    id = String.trim(id || "")

    socket = assign(socket, resolver_id: id)

    if id == "" do
      assign(socket, resolver_result: nil, resolver_error: "Enter a prefixed ID.")
    else
      case AshPrefixedId.get([Catalog], id) do
        {:ok, record} ->
          assign(socket, resolver_result: describe_record(record, id), resolver_error: nil)

        {:error, error} ->
          assign(socket, resolver_result: nil, resolver_error: inspect(error))
      end
    end
  end

  defp raw_uuid(nil), do: nil
  defp raw_uuid(id), do: AshPrefixedId.to_uuid_string!(id)

  defp legacy_todo_id(nil), do: nil
  defp legacy_todo_id(%Todo{id: "todo_" <> slug}), do: "task_#{slug}"

  defp prefix(id) do
    id
    |> String.split("_", parts: 2)
    |> List.first()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
    <main class="min-h-screen bg-zinc-950 text-zinc-100">
      <section class="mx-auto flex max-w-7xl flex-col gap-8 px-5 py-6 sm:px-8 lg:px-10">
        <div class="flex flex-col gap-4 border-b border-zinc-800 pb-6 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-300">
              AshPrefixedId demo
            </p>
            <h1 class="mt-3 text-3xl font-semibold tracking-normal text-white sm:text-4xl">
              Postgres resources, APIs, TypeScript RPC, LiveView
            </h1>
            <p class="mt-3 max-w-3xl text-sm leading-6 text-zinc-400">
              Same Ash resources drive PostgreSQL tables, GraphQL fields, JSON:API routes, generated TypeScript RPC, and this LiveView list.
            </p>
          </div>

          <button
            type="button"
            phx-click="create_chain"
            class="inline-flex min-h-11 items-center justify-center rounded-md bg-cyan-300 px-4 text-sm font-semibold text-zinc-950 transition hover:bg-cyan-200 focus:outline-none focus:ring-2 focus:ring-cyan-200 focus:ring-offset-2 focus:ring-offset-zinc-950"
          >
            Create linked records
          </button>
        </div>

        <div class="grid gap-4 border-b border-zinc-800 pb-6 sm:grid-cols-3">
          <.metric label="Teams" value={length(@teams)} prefix="team_" />
          <.metric label="Projects" value={length(@projects)} prefix="proj_" />
          <.metric label="Todos" value={length(@todos)} prefix="todo_" />
        </div>

        <section class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_360px]">
          <div class="overflow-hidden rounded-lg border border-zinc-800 bg-zinc-900/70">
            <div class="flex items-center justify-between border-b border-zinc-800 px-4 py-3">
              <div>
                <h2 class="text-sm font-semibold text-white">Relationship rows</h2>
                <p class="mt-1 text-xs text-zinc-500">
                  Loaded through Ash, backed by Postgres foreign keys.
                </p>
              </div>
              <span class="rounded bg-zinc-800 px-2 py-1 text-xs text-zinc-300">{@domain}</span>
            </div>

            <div class="overflow-x-auto">
              <table class="w-full min-w-[900px] text-left text-sm">
                <thead class="bg-zinc-950/80 text-xs uppercase tracking-wide text-zinc-500">
                  <tr>
                    <th class="px-4 py-3 font-medium">Todo</th>
                    <th class="px-4 py-3 font-medium">Todo ID</th>
                    <th class="px-4 py-3 font-medium">Project ID</th>
                    <th class="px-4 py-3 font-medium">Team ID</th>
                    <th class="px-4 py-3 font-medium">Raw UUID in Postgres</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-zinc-800">
                  <tr :for={todo <- @todos} class="transition hover:bg-zinc-800/60">
                    <td class="px-4 py-4">
                      <div class="font-medium text-white">{todo.title}</div>
                      <div class="mt-1 text-xs text-zinc-500">
                        {todo.project.name} / {todo.project.team.name}
                      </div>
                    </td>
                    <td class="px-4 py-4">
                      <.link
                        navigate={~p"/todos/#{todo}"}
                        class="break-all font-mono text-xs text-cyan-200 transition hover:text-cyan-100"
                      >
                        {todo.id}
                      </.link>
                      <button
                        type="button"
                        phx-click="resolve_id"
                        phx-value-id={legacy_todo_id(todo)}
                        class="mt-2 block break-all text-left font-mono text-xs text-zinc-500 transition hover:text-zinc-300"
                      >
                        legacy {legacy_todo_id(todo)}
                      </button>
                    </td>
                    <td class="px-4 py-4 font-mono text-xs text-amber-200">{todo.project_id}</td>
                    <td class="px-4 py-4 font-mono text-xs text-emerald-200">
                      {todo.project.team_id}
                    </td>
                    <td class="px-4 py-4 font-mono text-xs text-zinc-400">{raw_uuid(todo.id)}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <aside class="space-y-6">
            <div class="rounded-lg border border-zinc-800 bg-zinc-900/70 p-4">
              <h2 class="text-sm font-semibold text-white">Global resolver</h2>
              <p class="mt-1 text-xs leading-5 text-zinc-500">
                Uses AshPrefixedId.get/3 across the Catalog domain.
              </p>

              <.form
                for={%{}}
                as={:resolver}
                id="id-resolver"
                phx-submit="resolve_id"
                class="mt-4 space-y-3"
              >
                <input
                  type="text"
                  name="resolver[id]"
                  value={@resolver_id}
                  class="min-h-11 w-full rounded-md border border-zinc-700 bg-zinc-950 px-3 font-mono text-xs text-zinc-100 outline-none transition placeholder:text-zinc-600 focus:border-cyan-300"
                  placeholder="todo_..., task_..., proj_..., team_..."
                />
                <button
                  type="submit"
                  class="inline-flex min-h-10 w-full items-center justify-center rounded-md bg-cyan-300 px-3 text-sm font-semibold text-zinc-950 transition hover:bg-cyan-200"
                >
                  Resolve ID
                </button>
              </.form>

              <div :if={@resolver_result} class="mt-4 border-l border-cyan-300 pl-3">
                <div class="text-xs font-semibold uppercase tracking-wide text-cyan-200">
                  {@resolver_result.type}
                </div>
                <div class="mt-1 text-sm font-medium text-white">{@resolver_result.label}</div>
                <div class="mt-2 break-all font-mono text-xs text-zinc-400">
                  requested {@resolver_result.requested_id}
                </div>
                <div class="mt-1 break-all font-mono text-xs text-cyan-200">
                  canonical {@resolver_result.id}
                </div>
              </div>

              <div :if={@resolver_error} class="mt-4 border-l border-rose-500 pl-3">
                <div class="text-xs font-semibold uppercase tracking-wide text-rose-200">
                  Resolver error
                </div>
                <div class="mt-1 break-all font-mono text-xs text-rose-100">
                  {@resolver_error}
                </div>
              </div>
            </div>

            <div class="rounded-lg border border-zinc-800 bg-zinc-900/70 p-4">
              <h2 class="text-sm font-semibold text-white">API proof points</h2>
              <div class="mt-4 space-y-4 text-sm">
                <.proof label="GraphQL" path="/gql/playground" text="listTodos, getTodo, createTodo" />
                <.proof
                  label="JSON:API"
                  path="/api/json/catalog/todos"
                  text="type=todo, relationships by prefixed FK"
                />
                <.proof label="TypeScript" path="/rpc/run" text="Todo IDs are branded strings" />
                <.proof
                  label="Routes"
                  path="/todos/:id"
                  text="Phoenix.Param emits prefixed todo IDs"
                />
                <.proof
                  label="Storage"
                  path="Postgres uuid"
                  text="IDs render prefixed; columns stay uuid"
                />
              </div>
            </div>
          </aside>
        </section>

        <section class="grid gap-6 lg:grid-cols-2">
          <.resource_list title="Teams" items={@teams} />
          <.resource_list title="Projects" items={@projects} />
        </section>
      </section>
    </main>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :prefix, :string, required: true

  def metric(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-800 bg-zinc-900/70 px-4 py-3">
      <div class="text-xs uppercase tracking-wide text-zinc-500">{@label}</div>
      <div class="mt-2 flex items-end justify-between gap-3">
        <div class="text-3xl font-semibold text-white">{@value}</div>
        <div class="font-mono text-xs text-cyan-300">{@prefix}</div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :path, :string, required: true
  attr :text, :string, required: true

  def proof(assigns) do
    ~H"""
    <div class="border-l border-zinc-700 pl-3">
      <div class="flex items-center justify-between gap-3">
        <span class="text-xs font-semibold uppercase tracking-wide text-zinc-400">{@label}</span>
        <span class="font-mono text-xs text-zinc-500">{@path}</span>
      </div>
      <p class="mt-1 text-zinc-300">{@text}</p>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :items, :list, required: true

  def resource_list(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-800 bg-zinc-900/70">
      <h2 class="border-b border-zinc-800 px-4 py-3 text-sm font-semibold text-white">{@title}</h2>
      <div class="divide-y divide-zinc-800">
        <div :for={item <- @items} class="px-4 py-3">
          <div class="flex items-center justify-between gap-3">
            <div class="font-medium text-white">{item.name}</div>
            <div class="font-mono text-xs text-zinc-500">{prefix(item.id)}</div>
          </div>
          <div class="mt-2 break-all font-mono text-xs text-cyan-200">{item.id}</div>
          <div class="mt-1 break-all font-mono text-xs text-zinc-500">{raw_uuid(item.id)}</div>
        </div>
      </div>
    </div>
    """
  end

  defp describe_record(%Team{} = team, requested_id) do
    %{type: "Team", label: team.name, id: team.id, requested_id: requested_id}
  end

  defp describe_record(%Project{} = project, requested_id) do
    %{type: "Project", label: project.name, id: project.id, requested_id: requested_id}
  end

  defp describe_record(%Todo{} = todo, requested_id) do
    %{
      type: "Todo",
      label: todo.title,
      id: todo.id,
      requested_id: requested_id
    }
  end
end

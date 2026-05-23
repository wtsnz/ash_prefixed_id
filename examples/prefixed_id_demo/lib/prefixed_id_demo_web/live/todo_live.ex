defmodule PrefixedIdDemoWeb.TodoLive do
  use PrefixedIdDemoWeb, :live_view

  alias PrefixedIdDemo.Catalog
  alias PrefixedIdDemo.Catalog.Todo

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, assign_todo(socket, id)}
  end

  defp assign_todo(socket, id) do
    case AshPrefixedId.get([Catalog], id) do
      {:ok, %Todo{} = todo} ->
        todo = Ash.load!(todo, project: [:team])

        assign(socket,
          requested_id: id,
          todo: todo,
          raw_uuid: AshPrefixedId.to_uuid_string!(todo.id),
          error: nil
        )

      {:ok, record} ->
        assign(socket,
          requested_id: id,
          todo: nil,
          raw_uuid: nil,
          error: "Expected a todo ID, got #{inspect(record.__struct__)}"
        )

      {:error, error} ->
        assign(socket,
          requested_id: id,
          todo: nil,
          raw_uuid: nil,
          error: inspect(error)
        )
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
    <main class="min-h-screen bg-zinc-950 text-zinc-100">
      <section class="mx-auto flex max-w-4xl flex-col gap-6 px-5 py-6 sm:px-8 lg:px-10">
        <.link
          navigate={~p"/"}
          class="text-sm font-medium text-cyan-300 transition hover:text-cyan-200"
        >
          Back to catalog
        </.link>

        <div class="border-b border-zinc-800 pb-6">
          <p class="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-300">
            Phoenix.Param route
          </p>
          <h1 class="mt-3 text-3xl font-semibold tracking-normal text-white">
            Todo detail by prefixed ID
          </h1>
          <p class="mt-3 font-mono text-xs text-zinc-500">
            GET /todos/{@requested_id}
          </p>
        </div>

        <div :if={@todo} class="rounded-lg border border-zinc-800 bg-zinc-900/70 p-5">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <h2 class="text-xl font-semibold text-white">{@todo.title}</h2>
              <p class="mt-2 text-sm text-zinc-400">
                {@todo.project.name} / {@todo.project.team.name}
              </p>
            </div>
            <span class="rounded bg-zinc-800 px-2 py-1 font-mono text-xs text-cyan-200">
              {@todo.id}
            </span>
          </div>

          <dl class="mt-6 grid gap-4 sm:grid-cols-2">
            <div>
              <dt class="text-xs uppercase tracking-wide text-zinc-500">Requested ID</dt>
              <dd class="mt-1 break-all font-mono text-xs text-zinc-300">{@requested_id}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-wide text-zinc-500">Postgres UUID</dt>
              <dd class="mt-1 break-all font-mono text-xs text-zinc-300">{@raw_uuid}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-wide text-zinc-500">Project ID</dt>
              <dd class="mt-1 break-all font-mono text-xs text-amber-200">{@todo.project_id}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-wide text-zinc-500">Team ID</dt>
              <dd class="mt-1 break-all font-mono text-xs text-emerald-200">
                {@todo.project.team_id}
              </dd>
            </div>
          </dl>
        </div>

        <div :if={@error} class="rounded-lg border border-rose-900/70 bg-rose-950/40 p-5">
          <h2 class="text-sm font-semibold text-rose-200">Unable to resolve todo</h2>
          <p class="mt-2 font-mono text-xs text-rose-100">{@error}</p>
        </div>
      </section>
    </main>
    """
  end
end

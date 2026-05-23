defmodule PrefixedIdDemoWeb.CatalogLiveTest do
  use PrefixedIdDemoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias PrefixedIdDemo.Catalog.DemoData

  test "GET /", %{conn: conn} do
    %{todo: todo} = DemoData.create_chain!()
    legacy_id = legacy_todo_id(todo)

    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "AshPrefixedId demo"
    assert html =~ "Global resolver"
    assert html =~ legacy_id
    assert html =~ todo.id
    assert html =~ ~s(href="/todos/#{todo.id}")
  end

  test "global resolver accepts a legacy todo prefix", %{conn: conn} do
    %{todo: todo} = DemoData.create_chain!()
    legacy_id = legacy_todo_id(todo)

    {:ok, view, _html} = live(conn, ~p"/")

    html =
      view
      |> form("#id-resolver", resolver: %{id: legacy_id})
      |> render_submit()

    assert html =~ "requested #{legacy_id}"
    assert html =~ "canonical #{todo.id}"
  end

  test "todo detail route uses Phoenix.Param prefixed IDs", %{conn: conn} do
    %{todo: todo} = DemoData.create_chain!()

    conn = get(conn, ~p"/todos/#{todo}")
    html = html_response(conn, 200)

    assert html =~ "Phoenix.Param route"
    assert html =~ todo.title
    assert html =~ todo.id
    assert html =~ AshPrefixedId.to_uuid_string!(todo.id)
  end

  defp legacy_todo_id(%{id: "todo_" <> slug}), do: "task_#{slug}"
end

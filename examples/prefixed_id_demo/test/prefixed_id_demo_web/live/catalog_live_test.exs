defmodule PrefixedIdDemoWeb.CatalogLiveTest do
  use PrefixedIdDemoWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "AshPrefixedId demo"
  end
end

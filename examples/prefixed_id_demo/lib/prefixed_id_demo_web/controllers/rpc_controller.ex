defmodule PrefixedIdDemoWeb.RpcController do
  use PrefixedIdDemoWeb, :controller

  def run(conn, params) do
    json(conn, AshTypescript.Rpc.run_action(:prefixed_id_demo, conn, params))
  end

  def validate(conn, params) do
    json(conn, AshTypescript.Rpc.validate_action(:prefixed_id_demo, conn, params))
  end
end

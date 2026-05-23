defmodule AshPrefixedId.Test.Repo do
  @moduledoc false

  use AshPostgres.Repo, otp_app: :ash_prefixed_id

  def min_pg_version do
    %Version{major: 17, minor: 0, patch: 0}
  end

  def installed_extensions do
    ["ash-functions", AshPrefixedId.PostgresExtension]
  end
end

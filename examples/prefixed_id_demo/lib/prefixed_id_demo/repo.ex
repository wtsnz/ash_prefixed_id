defmodule PrefixedIdDemo.Repo do
  use AshPostgres.Repo, otp_app: :prefixed_id_demo

  def min_pg_version do
    %Version{major: 17, minor: 0, patch: 0}
  end

  def installed_extensions do
    ["ash-functions", "uuid-ossp", "citext", AshPrefixedId.PostgresExtension]
  end
end

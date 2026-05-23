import Config

config :ash, :disable_async?, true
config :ash, :validate_domain_resource_inclusion?, false
config :ash, :validate_domain_config_inclusion?, false
config :ash, :keep_read_action_loads_when_loading?, false

config :ecto_sqlite3, :uuid_type, :binary

config :ash_prefixed_id, AshPrefixedId.Test.SqliteRepo,
  database: Path.expand("../tmp/ash_prefixed_id_sqlite_test.db", __DIR__),
  pool_size: 1,
  show_sensitive_data_on_connection_error: true

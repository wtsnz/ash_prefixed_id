defmodule AshPrefixedId.PrefixTest do
  use ExUnit.Case, async: true

  alias AshPrefixedId.Prefix

  test "validates TypeID-style prefixes" do
    assert Prefix.validate("user") == :ok
    assert Prefix.validate("billing_account") == :ok

    assert Prefix.validate(:user) == {:error, :not_a_string}
    assert Prefix.validate("") == {:error, :empty}
    assert Prefix.validate(String.duplicate("a", 64)) == {:error, :too_long}
    assert Prefix.validate("User") == {:error, :invalid_start}
    assert Prefix.validate("_user") == {:error, :invalid_start}
    assert Prefix.validate("user_") == {:error, :invalid_end}
    assert Prefix.validate("user-id") == {:error, :invalid_characters}
  end

  test "validate!/1 returns the prefix or raises with a useful message" do
    assert Prefix.validate!("user") == "user"

    assert_raise ArgumentError, ~r/must start with a lowercase ASCII letter/, fn ->
      Prefix.validate!("User")
    end
  end
end

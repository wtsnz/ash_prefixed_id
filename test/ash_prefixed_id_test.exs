defmodule AshPrefixedIdTest do
  use ExUnit.Case, async: true

  alias AshPrefixedId
  alias AshPrefixedId.Test.Domain
  alias AshPrefixedId.Test.Resources.Comment
  alias AshPrefixedId.Test.Resources.LegacyArticle
  alias AshPrefixedId.Test.Resources.Post
  alias AshPrefixedId.Test.Resources.PostgresNativePost
  alias AshPrefixedId.Test.Resources.PostgresPost
  alias AshPrefixedId.Test.Resources.Unrelated

  test "it replaces the primary key with an object id" do
    assert [pk] = Ash.Resource.Info.primary_key(Post)
    attr = Ash.Resource.Info.attribute(Post, pk)
    assert attr.name == :id
    assert attr.type == Post.ObjectId
  end

  test "relationships" do
    post =
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Designing APIs for humans"})
      |> Ash.create!()

    assert "post_" <> id = post.id
    assert AshPrefixedId.find_resource_for_id([Domain], post.id) == Post

    assert_raise Ash.Error.Invalid, ~r/incorrect object prefix/, fn ->
      Comment
      |> Ash.Changeset.for_create(:create, %{
        post_id: "florb_#{id}",
        body: "I like this"
      })
      |> Ash.create!()
    end

    comment =
      Comment
      |> Ash.Changeset.for_create(:create, %{
        post_id: post.id,
        body: "I like this"
      })
      |> Ash.create!()

    assert "c_" <> _ = comment.id
  end

  test "BelongsToAttribute auto-creates FK with ObjectId type" do
    # Comment.post_id should be auto-created as Post.ObjectId
    # (no manual attribute_type: needed)
    attr = Ash.Resource.Info.attribute(Comment, :post_id)
    assert attr != nil
    assert attr.type == Post.ObjectId
  end

  test "ObjectId modules expose API boundary types" do
    assert Post.ObjectId.graphql_type([]) == :id
    assert Post.ObjectId.graphql_input_type([]) == :id
    assert Post.ObjectId.typescript_type_name() == "string"

    assert LegacyArticle.ObjectId.typescript_type_name() ==
             ~s(string & { readonly __prefix: "article" | "old_article" })

    assert AshPrefixedId.AnyPrefixedId.graphql_type([]) == :id
    assert AshPrefixedId.AnyPrefixedId.graphql_input_type([]) == :id
    assert AshPrefixedId.AnyPrefixedId.typescript_type_name() == "string"
  end

  test "Postgres migration defaults use uuid_generate_v7 when enabled" do
    assert AshPostgres.DataLayer.Info.migration_defaults(PostgresPost)[:id] ==
             "fragment(\"uuid_generate_v7()\")"
  end

  test "Postgres migration defaults can use native PostgreSQL uuidv7" do
    assert AshPostgres.DataLayer.Info.migration_defaults(PostgresNativePost)[:id] ==
             "fragment(\"uuidv7()\")"
  end

  test "invalid Postgres migration default functions fail during compilation" do
    module = "AshPrefixedId.Test.Resources.InvalidDefault#{System.unique_integer([:positive])}"

    code = """
    defmodule #{module} do
      use Ash.Resource,
        domain: AshPrefixedId.Test.Domain,
        data_layer: AshPostgres.DataLayer,
        extensions: [AshPrefixedId]

      prefixed_id do
        prefix "invalid_default"
        migration_default?(true)
        migration_default_function "uuidv7(); drop table todos"
      end

      postgres do
        table "invalid_defaults"
        repo AshPrefixedId.Test.Repo
      end

      attributes do
        uuid_v7_primary_key(:id)
      end
    end
    """

    assert_raise Spark.Error.DslError, ~r/Invalid migration_default_function/, fn ->
      Code.compile_string(code)
    end
  end

  test "parse/1 exposes prefixed ID parts" do
    uuid = "5d446d08-df6a-404d-a1e5-decc78429b3d"
    id = AshPrefixedId.to_prefixed_id(uuid, "billing_account")

    assert {:ok,
            %AshPrefixedId.ParsedId{
              prefix: "billing_account",
              uuid: ^uuid,
              uuid_binary: uuid_binary,
              slug: slug
            }} = AshPrefixedId.parse(id)

    assert byte_size(uuid_binary) == 16
    assert id == "billing_account_#{slug}"
    assert AshPrefixedId.parse!(id).prefix == "billing_account"
    assert AshPrefixedId.valid?(id)
    assert AshPrefixedId.prefix(id) == {:ok, "billing_account"}
    assert AshPrefixedId.prefix!(id) == "billing_account"
  end

  test "parse/1 reports invalid ID reasons" do
    "user_" <> slug = AshPrefixedId.to_prefixed_id(Ecto.UUID.bingenerate(), "user")

    assert AshPrefixedId.parse("not-an-id") == {:error, :missing_separator}
    assert AshPrefixedId.parse("_abc") == {:error, :empty_prefix}
    assert AshPrefixedId.parse("user_") == {:error, :empty_suffix}
    assert AshPrefixedId.parse("User_#{slug}") == {:error, :invalid_start}
    assert AshPrefixedId.parse("user_not_base58!") == {:error, :invalid_suffix}
    assert AshPrefixedId.parse(123) == {:error, :not_a_string}

    refute AshPrefixedId.valid?("not-an-id")

    assert_raise ArgumentError, ~r/invalid prefixed ID/, fn ->
      AshPrefixedId.parse!("not-an-id")
    end
  end

  test "invalid resource prefixes fail during compilation" do
    module = "AshPrefixedId.Test.Resources.InvalidPrefix#{System.unique_integer([:positive])}"

    code = """
    defmodule #{module} do
      use Ash.Resource,
        domain: AshPrefixedId.Test.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPrefixedId]

      prefixed_id do
        prefix "Invalid"
      end

      attributes do
        uuid_primary_key(:id)
      end
    end
    """

    assert_raise Spark.Error.DslError, ~r/Invalid prefixed ID prefix/, fn ->
      Code.compile_string(code)
    end
  end

  test "custom UUID primary key types fail during compilation" do
    module = "AshPrefixedId.Test.Resources.CustomUuid#{System.unique_integer([:positive])}"

    code = """
    defmodule #{module} do
      use Ash.Resource,
        domain: AshPrefixedId.Test.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPrefixedId]

      prefixed_id do
        prefix "custom_uuid"
      end

      attributes do
        attribute :id, AshPrefixedId.Test.CustomUuidType do
          primary_key?(true)
          allow_nil?(false)
          public?(true)
        end
      end
    end
    """

    assert_raise Spark.Error.DslError, ~r/Expected primary key type to be Ash.Type.UUID/, fn ->
      Code.compile_string(code)
    end
  end

  test "duplicate legacy prefixes fail during compilation" do
    module = "AshPrefixedId.Test.Resources.DuplicateLegacy#{System.unique_integer([:positive])}"

    code = """
    defmodule #{module} do
      use Ash.Resource,
        domain: AshPrefixedId.Test.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshPrefixedId]

      prefixed_id do
        prefix "account"
        legacy_prefixes ["account"]
      end

      attributes do
        uuid_primary_key(:id)
      end
    end
    """

    assert_raise Spark.Error.DslError, ~r/Duplicate prefixed ID prefix/, fn ->
      Code.compile_string(code)
    end
  end

  test "find_resource_for_prefix/2" do
    assert AshPrefixedId.find_resource_for_prefix([Domain], "post") == Post
    assert AshPrefixedId.find_resource_for_prefix([Domain], "old_article") == LegacyArticle
    assert AshPrefixedId.find_resource_for_prefix([Domain], "florb") == nil
  end

  test "find_resource_for_id/2" do
    assert AshPrefixedId.find_resource_for_id([Domain], "post_CWzLBdFy2f1XhrtesFferY") == Post
    assert AshPrefixedId.find_resource_for_id([Domain], "florb_CWzLBdFy2f1XhrtesFferY") == nil
  end

  test "resource/2 resolves resources with explicit lookup errors" do
    assert AshPrefixedId.resource([Domain], "post_CWzLBdFy2f1XhrtesFferY") == {:ok, Post}
    assert AshPrefixedId.resource!([Domain], "post_CWzLBdFy2f1XhrtesFferY") == Post

    assert AshPrefixedId.resources_for_prefix([Domain], "old_article") == [LegacyArticle]

    assert AshPrefixedId.resource([Domain], "florb_CWzLBdFy2f1XhrtesFferY") ==
             {:error, :unknown_prefix}

    assert AshPrefixedId.resource([Domain], "not-an-id") ==
             {:error, {:invalid_id, :missing_separator}}

    assert {:error, {:ambiguous_prefix, "c", resources}} =
             AshPrefixedId.resource([Domain], "c_CWzLBdFy2f1XhrtesFferY")

    assert Enum.sort(resources) == Enum.sort([Comment, Unrelated])

    assert_raise ArgumentError, ~r/unknown prefixed ID prefix/, fn ->
      AshPrefixedId.resource!([Domain], "florb_CWzLBdFy2f1XhrtesFferY")
    end
  end

  test "get/3 and get!/3 fetch records by global prefixed ID" do
    post =
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Global lookup"})
      |> Ash.create!()

    assert {:ok, fetched} = AshPrefixedId.get([Domain], post.id)
    assert fetched.id == post.id
    assert fetched.title == "Global lookup"

    assert AshPrefixedId.get!([Domain], post.id).id == post.id

    assert AshPrefixedId.get([Domain], "florb_CWzLBdFy2f1XhrtesFferY") ==
             {:error, :unknown_prefix}
  end

  test "map_prefixes_to_resources/1" do
    assert %{"post" => [Post], "c" => [Unrelated, Comment], "old_article" => [LegacyArticle]} =
             AshPrefixedId.map_prefixes_to_resources([Domain])
  end

  test "prefixes_for_resource/1 returns primary and legacy prefixes" do
    assert AshPrefixedId.prefixes_for_resource(LegacyArticle) == ["article", "old_article"]
    assert AshPrefixedId.prefixes_for_resource(Unrelated) == ["c"]
  end

  test "ObjectId types accept legacy prefixes and return primary prefixes from storage" do
    "article_" <> slug = id = LegacyArticle.ObjectId.generator([]) |> Enum.take(1) |> hd()
    legacy_id = "old_article_#{slug}"

    assert {:ok, ^id} = LegacyArticle.ObjectId.cast_input(legacy_id, [])
    assert {:ok, uuid_binary} = LegacyArticle.ObjectId.dump_to_native(legacy_id, [])
    assert {:ok, ^id} = LegacyArticle.ObjectId.cast_stored(uuid_binary, [])
  end

  test "legacy prefixes are canonicalized for primary key lookups" do
    article =
      LegacyArticle
      |> Ash.Changeset.for_create(:create, %{title: "Legacy lookup"})
      |> Ash.create!()

    "article_" <> slug = article.id
    legacy_id = "old_article_#{slug}"

    assert {:ok, fetched} = Ash.get(LegacyArticle, legacy_id)
    assert fetched.id == article.id
  end

  test "find_duplicate_prefixes" do
    assert %{"c" => [Unrelated, Comment]} == AshPrefixedId.find_duplicate_prefixes([Domain])
  end
end

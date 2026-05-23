defmodule AshPrefixedId.SqliteTest do
  use ExUnit.Case, async: false

  alias AshPrefixedId.Test.SqliteDomain
  alias AshPrefixedId.Test.SqliteRepo
  alias AshPrefixedId.Test.SqliteResources.Comment
  alias AshPrefixedId.Test.SqliteResources.LegacyArticle
  alias AshPrefixedId.Test.SqliteResources.Post

  setup_all do
    database = SqliteRepo.config()[:database]
    File.mkdir_p!(Path.dirname(database))
    File.rm(database)

    start_supervised!(SqliteRepo)
    create_tables!()

    on_exit(fn ->
      File.rm(database)
    end)

    :ok
  end

  setup do
    reset_tables!()
    :ok
  end

  test "AshSqlite stores raw UUID values while Ash sees prefixed IDs" do
    post =
      Post
      |> Ash.Changeset.for_create(:create, %{title: "SQLite proof"})
      |> Ash.create!()

    assert "sqlite_post_" <> _ = post.id
    post_id = post.id

    %{rows: [[stored_id]]} = SqliteRepo.query!("SELECT id FROM ashsqlite_posts")

    assert is_binary(stored_id)
    assert stored_id != post.id
    assert byte_size(stored_id) == 16
    assert {:ok, ^post_id} = Post.ObjectId.cast_stored(stored_id, [])

    assert Ash.get!(Post, post.id).id == post.id
    assert {:ok, fetched} = AshPrefixedId.get([SqliteDomain], post.id)
    assert fetched.id == post.id
  end

  test "AshSqlite belongs_to foreign keys use destination ObjectId types" do
    assert Ash.Resource.Info.attribute(Comment, :post_id).type == Post.ObjectId

    post =
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Relationships"})
      |> Ash.create!()

    "sqlite_post_" <> slug = post.id

    assert_raise Ash.Error.Invalid, ~r/incorrect object prefix/, fn ->
      Comment
      |> Ash.Changeset.for_create(:create, %{
        body: "Wrong prefix",
        post_id: "sqlite_article_#{slug}"
      })
      |> Ash.create!()
    end

    comment =
      Comment
      |> Ash.Changeset.for_create(:create, %{
        body: "Right prefix",
        post_id: post.id
      })
      |> Ash.create!()

    assert "sqlite_comment_" <> _ = comment.id
    assert comment.post_id == post.id
    post_id = post.id

    %{rows: [[stored_post_id]]} = SqliteRepo.query!("SELECT post_id FROM ashsqlite_comments")

    assert byte_size(stored_post_id) == 16
    assert {:ok, ^post_id} = Post.ObjectId.cast_stored(stored_post_id, [])

    comment = Ash.load!(comment, :post)
    assert comment.post.id == post.id
  end

  test "AshSqlite lookups accept legacy prefixes and return canonical IDs" do
    article =
      LegacyArticle
      |> Ash.Changeset.for_create(:create, %{title: "Legacy SQLite"})
      |> Ash.create!()

    "sqlite_article_" <> slug = article.id
    legacy_id = "sqlite_old_article_#{slug}"

    assert {:ok, fetched} = Ash.get(LegacyArticle, legacy_id)
    assert fetched.id == article.id

    assert {:ok, fetched} = AshPrefixedId.get([SqliteDomain], legacy_id)
    assert fetched.id == article.id
  end

  defp create_tables! do
    SqliteRepo.query!("PRAGMA foreign_keys = ON")

    SqliteRepo.query!("""
    CREATE TABLE IF NOT EXISTS ashsqlite_posts (
      id BLOB PRIMARY KEY,
      title TEXT NOT NULL
    )
    """)

    SqliteRepo.query!("""
    CREATE TABLE IF NOT EXISTS ashsqlite_comments (
      id BLOB PRIMARY KEY,
      body TEXT NOT NULL,
      post_id BLOB NOT NULL REFERENCES ashsqlite_posts(id)
    )
    """)

    SqliteRepo.query!("""
    CREATE TABLE IF NOT EXISTS ashsqlite_legacy_articles (
      id BLOB PRIMARY KEY,
      title TEXT NOT NULL
    )
    """)
  end

  defp reset_tables! do
    SqliteRepo.query!("DELETE FROM ashsqlite_comments")
    SqliteRepo.query!("DELETE FROM ashsqlite_posts")
    SqliteRepo.query!("DELETE FROM ashsqlite_legacy_articles")
  end
end

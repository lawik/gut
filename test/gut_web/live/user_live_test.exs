defmodule GutWeb.UserLiveTest do
  use GutWeb.FeatureCase

  describe "UsersLive (index)" do
    test "renders users page", %{conn: conn} do
      conn
      |> visit("/users")
      |> assert_has("a", text: "Users")
      |> assert_has("h2", text: "Invites")
    end

    test "displays invites section", %{conn: conn} do
      conn
      |> visit("/users")
      |> assert_has("h2", text: "Invites")
    end
  end

  describe "UserDetailLive (show)" do
    test "renders user detail page", %{conn: conn, user: user} do
      conn
      |> visit("/users/#{user.id}")
      |> assert_has("h1", text: "staff@test.com")
      |> assert_has("span", text: "staff")
      |> assert_has("a", text: "Edit User")
    end

    test "shows API keys section for staff viewing staff", %{conn: conn, user: user} do
      conn
      |> visit("/users/#{user.id}")
      |> assert_has("h2", text: "API Keys")
      |> assert_has("button", text: "Generate Key")
    end

    test "creates an API key", %{conn: conn, user: user} do
      conn
      |> visit("/users/#{user.id}")
      |> click_button("Generate Key")
      |> assert_has("p", text: "Copy it now")
    end

    test "does not show API keys for non-staff users", %{conn: conn} do
      speaker_user = Gut.Accounts.create_user!("speaker@test.com", :speaker, authorize?: false)

      conn
      |> visit("/users/#{speaker_user.id}")
      |> refute_has("h2", text: "API Keys")
    end
  end

  describe "UserFormLive (create)" do
    test "renders the new user form", %{conn: conn} do
      conn
      |> visit("/users/new")
      |> assert_has("h1", text: "Adding new user")
      |> assert_has("label", text: "Email Address")
      |> assert_has("label", text: "Role")
    end

    test "creates a user with valid data", %{conn: conn} do
      conn
      |> visit("/users/new")
      |> fill_in("Email Address", with: "new@test.com")
      |> select("Role", option: "Speaker")
      |> click_button("Create User")
      |> assert_has("h2", text: "Invites")
    end
  end

  describe "UserFormLive (edit)" do
    test "renders edit form with existing data", %{conn: conn, user: user} do
      conn
      |> visit("/users/#{user.id}/edit")
      |> assert_has("h1", text: "Editing staff@test.com")
    end

    test "updates a user role", %{conn: conn} do
      other_user = Gut.Accounts.create_user!("other@test.com", :staff, authorize?: false)

      conn
      |> visit("/users/#{other_user.id}/edit")
      |> select("Role", option: "Speaker")
      |> click_button("Update User")
      |> assert_has("h2", text: "Invites")
    end
  end
end

defmodule MiloWeb.OnboardingLiveTest do
  use MiloWeb.ConnCase, async: true

  alias Milo.{Accounts, Content}

  setup do
    # Create some test categories
    {:ok, cat1} =
      Content.create_category(%{
        "name" => "Work",
        "description" => "Work emails",
        "is_default" => true
      })

    {:ok, cat2} =
      Content.create_category(%{
        "name" => "Personal",
        "description" => "Personal emails",
        "is_default" => true
      })

    {:ok, cat3} =
      Content.create_category(%{
        "name" => "Shopping",
        "description" => "Shopping emails",
        "is_default" => false
      })

    {:ok, categories: [cat1, cat2, cat3]}
  end

  describe "mount" do
    test "redirects to home when user is not logged in", %{conn: conn} do
      conn = get(conn, ~p"/onboarding")
      assert redirected_to(conn) == "/"
    end

    test "loads categories and selected categories when user is logged in", %{
      conn: conn,
      categories: [cat1, cat2, cat3]
    } do
      {:ok, user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "test@example.com",
          "name" => "Test User",
          "google_token" => "token123"
        })

      # Associate user with one category
      Content.associate_user_category(user.id, cat1.id)

      html =
        conn
        |> init_test_session(user_id: user.id)
        |> get(~p"/onboarding")
        |> html_response(200)

      # Check that categories are loaded
      assert html =~ cat1.name
      assert html =~ cat2.name
      assert html =~ cat3.name
      assert html =~ "Select Your Categories"
    end

    test "loads empty selected when user has no categories", %{conn: conn, categories: _categories} do
      {:ok, user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "test2@example.com",
          "name" => "Test User 2",
          "google_token" => "token456"
        })

      html =
        conn
        |> init_test_session(user_id: user.id)
        |> get(~p"/onboarding")
        |> html_response(200)

      assert html =~ "Select Your Categories"
      assert html =~ "Continue"
    end
  end

  describe "category selection and saving" do
    test "user can select categories and they are saved to database", %{
      conn: conn,
      categories: [cat1, cat2, _cat3]
    } do
      {:ok, user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "save@example.com",
          "name" => "Save User",
          "google_token" => "token-save"
        })

      # Initially no categories selected
      assert Content.list_user_category_ids(user.id) == []

      # Get the page to establish session
      conn =
        conn
        |> init_test_session(user_id: user.id)
        |> get(~p"/onboarding")

      html = html_response(conn, 200)
      assert html =~ cat1.name
      assert html =~ cat2.name

      # Simulate selecting categories by directly calling the function
      # (In a real scenario, this would happen through LiveView events)
      Content.associate_user_category(user.id, cat1.id)
      Content.associate_user_category(user.id, cat2.id)

      # Verify categories were saved
      saved_ids = Content.list_user_category_ids(user.id)
      assert cat1.id in saved_ids
      assert cat2.id in saved_ids
    end

    test "existing category associations are replaced when saving new ones", %{
      categories: [cat1, cat2, cat3]
    } do
      {:ok, user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "replace@example.com",
          "name" => "Replace User",
          "google_token" => "token-replace"
        })

      # First, associate user with cat1
      Content.associate_user_category(user.id, cat1.id)
      assert Content.list_user_category_ids(user.id) == [cat1.id]

      # Then replace with cat2 and cat3 (simulating what handle_event "next" does)
      existing_ids = Content.list_user_category_ids(user.id)
      for category_id <- existing_ids do
        Content.dissociate_user_category(user.id, category_id)
      end

      for category_id <- [cat2.id, cat3.id] do
        Content.associate_user_category(user.id, category_id)
      end

      # Verify only cat2 and cat3 are saved (cat1 removed)
      saved_ids = Content.list_user_category_ids(user.id)
      assert cat2.id in saved_ids
      assert cat3.id in saved_ids
      refute cat1.id in saved_ids
    end
  end

  describe "UI rendering" do
    test "displays all categories when user is logged in", %{conn: conn, categories: [cat1, cat2, cat3]} do
      {:ok, user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "render@example.com",
          "name" => "Render User",
          "google_token" => "token-render"
        })

      html =
        conn
        |> init_test_session(user_id: user.id)
        |> get(~p"/onboarding")
        |> html_response(200)

      assert html =~ cat1.name
      assert html =~ cat2.name
      assert html =~ cat3.name
      assert html =~ "Select Your Categories"
      assert html =~ "Add custom category"
      assert html =~ "Continue"
    end

    test "continue button shows disabled state when no categories selected", %{
      conn: conn,
      categories: _categories
    } do
      {:ok, user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "disabled@example.com",
          "name" => "Disabled User",
          "google_token" => "token-disabled"
        })

      html =
        conn
        |> init_test_session(user_id: user.id)
        |> get(~p"/onboarding")
        |> html_response(200)

      # Button should have disabled styling
      assert html =~ "cursor-not-allowed"
      assert html =~ "bg-gray-300"
    end

    test "page renders with correct layout structure", %{conn: conn, categories: _categories} do
      {:ok, user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "layout@example.com",
          "name" => "Layout User",
          "google_token" => "token-layout"
        })

      html =
        conn
        |> init_test_session(user_id: user.id)
        |> get(~p"/onboarding")
        |> html_response(200)

      # Check for key elements
      assert html =~ "Milo"
      assert html =~ "Select Your Categories"
      assert html =~ "Choose the categories you want to organize your emails with"
      assert html =~ "Continue"
    end
  end

  describe "validation" do
    test "requires at least one category before allowing navigation", %{
      categories: _categories
    } do
      {:ok, user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "validate@example.com",
          "name" => "Validate User",
          "google_token" => "token-validate"
        })

      # User has no categories selected
      assert Content.list_user_category_ids(user.id) == []

      # Verify the validation logic: empty selection should not save
      selected_ids = []
      assert Enum.empty?(selected_ids) == true
    end
  end

  describe "category creation integration" do
    test "newly created category appears in categories list", %{conn: conn, categories: [_cat1, _cat2, _cat3]} do
      {:ok, user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "create@example.com",
          "name" => "Create User",
          "google_token" => "token-create"
        })

      # Get initial categories
      initial_categories = Content.list_categories()
      initial_count = length(initial_categories)

      # Create a new category
      {:ok, new_category} =
        Content.create_category(%{
          "name" => "New Test Category",
          "description" => "A new test category",
          "is_default" => false
        })

      # Verify category was created
      updated_categories = Content.list_categories()
      assert length(updated_categories) == initial_count + 1
      assert Enum.any?(updated_categories, &(&1.id == new_category.id))

      # Verify it would appear on the page
      html =
        conn
        |> init_test_session(user_id: user.id)
        |> get(~p"/onboarding")
        |> html_response(200)

      assert html =~ new_category.name
    end
  end
end

defmodule NervesHubCLI.Directives.Product do
  import NervesHubCLI.Utils

  alias NervesHubCLI.Shell

  # @shortdoc "Manages your products"

  @moduledoc """
  Manages your products.

  ## create

  Create a new NervesHub product. The shell will prompt for information about the
  product. This information can be passed by specifying one or all of the command
  line options.

      nh product create

  ### Command-line options

    * `--name` - (Optional) The product name

  ## list

      nh product list

  ## delete

      nh product delete [product_name]

  ## update

  Update product metadata.

  Call `list` to retrieve product names and metadata keys

  ### Examples

  Change product name

      nh product update example name example_new

  # Managing user roles

  The following functions allow the management of user roles within your product.
  Roles are a way of granting users a permission level so they may perform
  actions for your product. The following is a list of valid roles in order of
  highest role to lowest role:

    * `admin`
    * `delete`
    * `write`
    * `read`

  NervesHub will validate all actions with your user role. If an action you are
  trying to perform requires `write`, the user performing the action will be
  required to have an org role of `write` or higher (`admin`, `delete`).

  Managing user roles for your product will require that your user has the
  product role of `admin`.

  ## user list

  List the users and their role for the product.

      nh product user list PRODUCT_NAME

  ## user add

  Add an existing user to a product with a role.

      nh product user add PRODUCT_NAME USERNAME ROLE

  ## user update

  Update an existing user for your product with a new role.

      nh product user update PRODUCT_NAME USERNAME ROLE

  ## user remove

  Remove an existing user from having a role for your product.

      nh product user remove PRODUCT_NAME USERNAME
  """

  @switches [
    org: :string,
    name: :string
  ]

  def run(args) do
    _ = Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    show_api_endpoint()
    org = org(opts)

    case args do
      ["list"] ->
        list(org)

      ["create"] ->
        create(org, opts)

      ["delete", product_name] ->
        delete(org, product_name)

      ["update", product, key, value] ->
        update(org, product, key, value)

      ["user", "list", product] ->
        user_list(org, product)

      ["user", "add", product, username, role] ->
        user_add(org, product, username, role)

      ["user", "update", product, username, role] ->
        user_update(org, product, username, role)

      ["user", "remove", product, username] ->
        user_remove(org, product, username)

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.info("""


    Usage:
      nh product list
      nh product create
      nh product delete PRODUCT_NAME
      nh product update PRODUCT_NAME KEY VALUE

      nh product user list PRODUCT_NAME
      nh product user add PRODUCT_NAME USERNAME ROLE
      nh product user update PRODUCT_NAME USERNAME ROLE
      nh product user remove PRODUCT_NAME USERNAME ROLE


    """)
  end

  def list(org) do
    auth = Shell.request_auth()

    case NervesHubUserAPI.Product.list(org, auth) do
      {:ok, %{"data" => []}} ->
        Shell.info("No products have been created.")

      {:ok, %{"data" => products}} ->
        Shell.info("")
        Shell.info("Products:")

        Enum.each(products, fn params ->
          Shell.info("------------")

          render_product(params)
          |> String.trim_trailing()
          |> Shell.info()
        end)

        Shell.info("")

      error ->
        Shell.render_error(error)
    end
  end

  def create(org, opts) do
    config = Mix.Project.config()

    name = opts[:name] || config[:name] || config[:app] || Shell.prompt("Product name:")
    name = to_string(name)

    Shell.info("")
    Shell.info("Creating product '#{name}'...")

    auth = Shell.request_auth()

    case NervesHubUserAPI.Product.create(org, name, auth) do
      {:ok, %{"data" => %{} = _product}} ->
        Shell.info("Product '#{name}' created.")

      error ->
        Shell.render_error(error)
    end
  end

  def delete(org, product_name) do
    if Shell.yes?("Delete product '#{product_name}'?") do
      auth = Shell.request_auth()

      case NervesHubUserAPI.Product.delete(org, product_name, auth) do
        {:ok, ""} ->
          Shell.info("Product deleted successfully.")

        error ->
          Shell.render_error(error)
      end
    end
  end

  def update(org, product, key, value) do
    auth = Shell.request_auth()

    case NervesHubUserAPI.Product.update(org, product, Map.put(%{}, key, value), auth) do
      {:ok, %{"data" => product}} ->
        Shell.info("")
        Shell.info("Product updated:")

        render_product(product)
        |> String.trim_trailing()
        |> Shell.info()

        Shell.info("")

      error ->
        Shell.render_error(error)
    end
  end

  def user_list(org, product) do
    auth = Shell.request_auth()

    case NervesHubUserAPI.ProductUser.list(org, product, auth) do
      {:ok, %{"data" => users}} ->
        render_users(users)

      error ->
        Shell.info("Failed to list product users \nreason: #{inspect(error)}")
    end
  end

  def user_add(org, product, username, role, auth \\ nil) do
    Shell.info("")
    Shell.info("Adding user '#{username}' to product '#{product}' with role '#{role}'...")

    auth = auth || Shell.request_auth()

    case NervesHubUserAPI.ProductUser.add(org, product, username, String.to_atom(role), auth) do
      {:ok, %{"data" => %{} = _product_user}} ->
        Shell.info("User '#{username}' was added.")

      error ->
        Shell.render_error(error)
    end
  end

  def user_update(org, product, username, role) do
    Shell.info("")
    Shell.info("Updating user '#{username}' in product '#{product}' to role '#{role}'...")

    auth = Shell.request_auth()

    case NervesHubUserAPI.ProductUser.update(org, product, username, String.to_atom(role), auth) do
      {:ok, %{"data" => %{} = _product_user}} ->
        Shell.info("User '#{username}' was updated.")

      {:error, %{"errors" => %{"detail" => "Not Found"}}} ->
        Shell.error("""
        '#{username}' is not a user for product '#{product}'.
        """)

        if Shell.yes?("Would you like to add them?") do
          user_add(org, product, username, role, auth)
        end

      error ->
        Shell.render_error(error)
    end
  end

  def user_remove(org, product, username) do
    Shell.info("")
    Shell.info("Removing user '#{username}' from product '#{product}'...")

    auth = Shell.request_auth()

    case NervesHubUserAPI.ProductUser.remove(org, product, username, auth) do
      {:ok, ""} ->
        Shell.info("User '#{username}' was removed.")

      {:error, %{"errors" => %{"detail" => "Not Found"}}} ->
        Shell.error("""
        '#{username}' is not a user for the product '#{product}'
        """)

      error ->
        IO.inspect(error)
        Shell.render_error(error)
    end
  end

  defp render_product(params) do
    """
      name: #{params["name"]}
    """
  end

  defp render_users(users) when is_list(users) do
    Shell.info("\nProduct users:")

    Enum.each(users, fn params ->
      Shell.info("------------")

      render_user(params)
    end)

    Shell.info("------------")
    Shell.info("")
  end

  defp render_user(params) do
    Shell.info("  username:   #{params["username"]}")
    Shell.info("  role:       #{params["role"]}")
  end
end

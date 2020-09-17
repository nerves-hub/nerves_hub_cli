defmodule NervesHubCLI.Directives.Org do
  import NervesHubCLI.Utils

  alias NervesHubCLI.Shell

  # @shortdoc "Manages an organization"

  @moduledoc """
  Manages an organization

  # Managing user roles

  The following functions allow the management of user roles within your organization.
  Roles are a way of granting users a permission level so they may perform
  actions for your org. The following is a list of valid roles in order of
  highest role to lowest role:

    * `admin`
    * `delete`
    * `write`
    * `read`

  NervesHub will validate all actions with your user role. If an action you are
  trying to perform requires `write`, the user performing the action will be
  required to have an org role of `write` or higher (`admin`, `delete`).

  Managing user roles in your org will require that your user has the org role of
  `admin`.

  ## user list

  List the users and their role for the organization.

      nh org user list

  ## user add

  Add an existing user to an org with a role.

      nh org user add USERNAME ROLE

  ## user update

  Update an existing user in your org with a new role.

      nh org user update USERNAME ROLE

  ## user remove

  Remove an existing user from having a role in your organization.

      nh org user remove USERNAME
  """

  @switches [
    org: :string
  ]

  def run(args) do
    _ = Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    show_api_endpoint()
    org = org(opts)

    case args do
      ["user", "list"] ->
        user_list(org)

      ["user", "add", username, role] ->
        user_add(org, username, role)

      ["user", "update", username, role] ->
        user_update(org, username, role)

      ["user", "remove", username] ->
        user_remove(org, username)

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.info("""


    Usage:
      nh org user list
      nh org user add USERNAME ROLE
      nh org user update USERNAME ROLE
      nh org user remove USERNAME


    """)
  end

  def user_list(org) do
    auth = Shell.request_auth()

    case NervesHubUserAPI.OrgUser.list(org, auth) do
      {:ok, %{"data" => users}} ->
        render_users(users)

      error ->
        Shell.info("Failed to list org users \nreason: #{inspect(error)}")
    end
  end

  def user_add(org, username, role, auth \\ nil) do
    Shell.info("")
    Shell.info("Adding user '#{username}' to org '#{org}' with role '#{role}'...")

    auth = auth || Shell.request_auth()

    case NervesHubUserAPI.OrgUser.add(org, username, String.to_atom(role), auth) do
      {:ok, %{"data" => %{} = _org_user}} ->
        Shell.info("User '#{username}' was added.")

      error ->
        Shell.render_error(error)
    end
  end

  def user_update(org, username, role) do
    Shell.info("")
    Shell.info("Updating user '#{username}' in org '#{org}' to role '#{role}'...")

    auth = Shell.request_auth()

    case NervesHubUserAPI.OrgUser.update(org, username, String.to_atom(role), auth) do
      {:ok, %{"data" => %{} = _org_user}} ->
        Shell.info("User '#{username}' was updated.")

      {:error, %{"errors" => %{"detail" => "Not Found"}}} ->
        Shell.error("""
        '#{username}' is not a user in the organization '#{org}'.
        """)

        if Shell.yes?("Would you like to add them?") do
          user_add(org, username, role, auth)
        end

      error ->
        Shell.render_error(error)
    end
  end

  def user_remove(org, username) do
    Shell.info("")
    Shell.info("Removing user '#{username}' from org '#{org}'...")

    auth = Shell.request_auth()

    case NervesHubUserAPI.OrgUser.remove(org, username, auth) do
      {:ok, ""} ->
        Shell.info("User '#{username}' was removed.")

      {:error, %{"errors" => %{"detail" => "Not Found"}}} ->
        Shell.error("""
        '#{username}' is not a user in the organization '#{org}'
        """)

      error ->
        IO.inspect(error)
        Shell.render_error(error)
    end
  end

  defp render_users(users) when is_list(users) do
    Shell.info("\nOrganization users:")

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

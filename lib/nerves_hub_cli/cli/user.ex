defmodule NervesHubCLI.CLI.User do
  import NervesHubCLI.CLI.Utils

  alias NervesHubCLI.CLI.Shell
  alias NervesHubCLI.Config

  @moduledoc """
  Manage your NervesHub user account.

  Users are authenticated to the NervesHub API with a user access token
  presented in each request.

  You can use `nh user auth` to authenticate with NervesHub,
  saving the token locally in your local config found in `$NERVES_HUB_HOME`

  Or this token can be manually supplied with the `NERVES_HUB_TOKEN` environment
  variable. This approach is recommended when using CLI in CI/CD systems.

  # Available commands

    - `whoami`  display which account is logged in
    - `auth`    authenticate with NervesHub
    - `logout`  logout from NervesHub

  ## whoami

  Check which account is currently logged in.

  This command is useful for verifying that you are logged in to the correct account.

  Usage:

      $ nh user whoami

  ## auth

  Authenticate with NervesHub.

  Usage:

      $ nh user auth

  Options:

    * `--note` - Note for the access token that is generated. Defaults to `hostname`

  ## logout

  Logout from the currently authenticated account.

  Usage:

      $ nh user logout

  Options:

    * `--path` - A local path where the certificate should be exported to.
  """

  @switches [
    note: :string,
    path: :string,
    use_peer_auth: :boolean
  ]

  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)

    case args do
      ["whoami"] ->
        whoami()

      ["auth"] ->
        auth(opts)

      ["logout"] ->
        logout()

      ["help"] ->
        render_help()

      [] ->
        render_help()

      unrecognized_command ->
        render_error(unrecognized_command)
    end
  end

  @spec render_error(unrecognized_command :: [String.t()]) :: no_return()
  def render_error(unrecognized_command) do
    Shell.unrecognized_command(unrecognized_command, "user")
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.module_help("User", @moduledoc)
  end

  def whoami do
    show_api_endpoint()
    auth = Shell.request_auth()

    case NervesHubCLI.API.User.me(auth) do
      {:ok, %{"data" => data}} ->
        %{"name" => name, "email" => email} = data

        Shell.info("""

        Name:  #{name}
        Email: #{email}
        """)

      error ->
        Shell.render_error(error)
    end
  end

  def auth(opts) do
    show_api_endpoint()

    username_or_email = Shell.prompt("\nUsername or email address:") |> String.trim()
    password = Shell.password_get("NervesHub password:") |> String.trim()
    Shell.info("Authenticating...")

    result = NervesHubCLI.API.User.login(username_or_email, password, opts[:note])

    case result do
      {:ok, %{"data" => %{"token" => token}}} ->
        _ = Config.put(:token, token)
        Shell.info("Success")

      {:error, %{"errors" => errors}} ->
        Shell.error("Account authentication failed \n")
        Shell.render_error(errors)

      error ->
        Shell.render_error(error)
    end
  end

  def logout() do
    # this isn't needed, but it looks better to show it
    show_api_endpoint()

    if Shell.yes?("\nAre you sure you want to logout?") do
      _ = NervesHubCLI.Config.delete(:token)
      :ok
    end
  end
end

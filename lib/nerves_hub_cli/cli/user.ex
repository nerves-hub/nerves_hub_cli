defmodule NervesHubCLI.CLI.User do
  import NervesHubCLI.CLI.Utils

  alias NervesHubCLI.{User, Config}
  alias NervesHubCLI.CLI.Shell

  @moduledoc """
  Manage your NervesHub user account.

  Users are authenticated to the NervesHub API with a user access token
  presented in each request. This token can be manually supplied with the
  `NERVES_HUB_TOKEN` or `NH_TOKEN` environment variables. Or you can use
  `nerves_hub user auth` to authenticate with the web, generate a token,
  and save it locally in your config in `$NERVES_HUB_HOME`

  ## whoami

      nerves_hub user whoami

  ## auth

      nerves_hub user auth

  ### Command-line options

    * `--note` - (Optional) Note for the access token that is generated. Defaults to `hostname`

  ## deauth

      nerves_hub user deauth

  ### Command-line options

    * `--path` - (Optional) A local location for exporting certificate.
  """

  @switches [
    note: :string,
    path: :string,
    use_peer_auth: :boolean
  ]

  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)

    show_api_endpoint()

    case args do
      ["whoami"] ->
        whoami()

      ["auth"] ->
        auth(opts)

      ["deauth"] ->
        deauth()

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.raise("""
    Invalid arguments to `nerves_hub user`.

    Usage:

      nerves_hub user whoami
      nerves_hub user auth
      nerves_hub user deauth

    Run `nerves_hub help user` for more information.
    """)
  end

  def whoami do
    auth = Shell.request_auth()

    case NervesHubCLI.API.User.me(auth) do
      {:ok, %{"data" => data}} ->
        %{"name" => name, "email" => email} = data

        Shell.info("""
        name:  #{name}
        email: #{email}
        """)

      error ->
        Shell.render_error(error)
    end
  end

  def auth(opts) do
    username_or_email = Shell.prompt("Username or email address:") |> String.trim()
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

  def deauth() do
    if Shell.yes?("Deauthorize the current user?") do
      User.deauth()
    end
  end
end

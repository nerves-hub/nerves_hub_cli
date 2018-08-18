defmodule Mix.Tasks.NervesHub.Key do
  use Mix.Task

  import Mix.NervesHubCLI.Utils
  alias NervesHubCLI.API
  alias Mix.NervesHubCLI.Shell

  @shortdoc "Manages your firmware signing keys"

  @moduledoc """
  Manages your firmware signing keys.

  Firmware signing keys consist of public and private keys. The `mix
  nerves_hub.key` task manages both pieces for you. Private signing keys are
  password-protected and are NEVER sent to NervesHub or any other server.
  Public keys, however, are registered with NervesHub.

  Signing keys are stored in `~/.nerves-hub/keys`. Keys may be shared between
  developers by copying the files in this folder.

  NervesHub can manage more than one key so that you can have different
  development and production keys in use. For example, production devices
  deployed with only the production public key will not accept firmware signed
  by development keys.

  To ensure that firmware includes keys registered with NervesHub, add the
  following entry in your project's `config.exs`:

    # List the public firmware signing keys to include on the device
    config :nerves_hub,
      public_keys: [:my_dev_key, :my_prod_key]

  ## list

  List the keys known to NervesHub

    mix nerves_hub.key list

  ### Command line options

    * `--local` - (Optional) Do not request key information from NervesHub

  ## create

  Create a new firmware signing key pair with the specified name and register
  the public key with NervesHub

    mix nerves_hub.key create NAME

  ### Command line options

    * `--local` - (Optional) Do not register the public key with NervesHub

  ## delete

  Delete a signing key locally and on NervesHub

    mix nerves_hub.key delete NAME

  ### Command line options

    * `--local` - (Optional) Perform the operation only locally defaults to
      `false` which will perform both local and remote operations
  """

  @switches [
    local: :boolean
  ]

  def run(args) do
    Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    org = org(opts)

    case args do
      ["list"] ->
        list(org, opts)

      ["create", name] ->
        create(name, org, opts)

      ["delete", name] ->
        delete(name, org, opts)

      _ ->
        render_help()
    end
  end

  def render_help() do
    Shell.raise("""
    Invalid arguments to `mix nerves_hub.key`.

    Usage:
      mix nerves_hub.key list
      mix nerves_hub.key create NAME
      mix nerves_hub.key delete NAME

    Run `mix help nerves_hub.key` for more information.
    """)
  end

  def list(org, opts) do
    if Keyword.get(opts, :local, false) do
      list_local(org)
    else
      list_remote(org)
    end
  end

  def list_local(org) do
    NervesHubCLI.Key.local_keys(org)
    |> Enum.map(&stringify/1)
    |> render_keys()
  end

  def list_remote(org) do
    auth = Shell.request_auth()

    case API.Key.list(org, auth) do
      {:ok, %{"data" => keys}} ->
        render_keys(keys)

      error ->
        Shell.info("Failed to list signing keys \nreason: #{inspect(error)}")
    end
  end

  def create(name, org, opts) do
    if NervesHubCLI.Key.exists?(org, name) do
      Shell.raise("The key #{name} already exists, aborting")
    else
      if Keyword.get(opts, :local, false) do
        with {:ok, key} <- create_local(name, org) do
          render_key(key)
        else
          error ->
            Shell.render_error(error)
        end
      else
        with {:ok, key} <- create_local(name, org),
             {:ok, %{"data" => key}} <- create_remote(name, key, org) do
          render_key(key)
        else
          error ->
            Shell.render_error(error)
        end
      end
    end
  end

  def delete(name, org, opts) do
    if Mix.shell().yes?("Delete signing key #{name}?") do
      if Keyword.get(opts, :local, false) do
        delete_local(name, org)
      else
        with {:ok, ""} <- delete_remote(name, org),
             :ok <- delete_local(name, org) do
          :ok
        else
          error ->
            Shell.render_error(error)
        end
      end
    end
  end

  def delete_remote(name, org) do
    auth = Shell.request_auth()
    Shell.info("Deleting remote signing key #{name}")
    API.Key.delete(org, name, auth)
  end

  # TODO handle file not found
  def delete_local(name, org) do
    Shell.info("Deleting local signing key #{name}")
    NervesHubCLI.Key.delete(org, name)
  end

  defp create_local(name, org) do
    Shell.info("\nPlease enter a local password for the firmware signing private key")
    key_password = Shell.password_get("Local key password:")

    with {:ok, public_key_file, _private_key_file} =
           NervesHubCLI.Key.create(org, name, key_password),
         {:ok, public_key} <- File.read(public_key_file) do
      {:ok, public_key}
    end
  end

  defp create_remote(name, key, org) do
    auth = Shell.request_auth()
    API.Key.create(org, name, key, auth)
  end

  defp render_keys([]) do
    Shell.info("No firmware signing keys have been created.")
  end

  defp render_keys(keys) when is_list(keys) do
    Shell.info("\nFirmware signing keys:")

    Enum.each(keys, fn params ->
      Shell.info("------------")

      render_key(params)
      |> String.trim_trailing()
      |> Shell.info()
    end)

    Shell.info("------------")
    Shell.info("")
  end

  defp render_key(params) do
    """
      name:       #{params["name"]}
      public key: #{params["key"]}
    """
  end
end

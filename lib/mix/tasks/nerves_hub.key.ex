defmodule Mix.Tasks.NervesHub.Key do
  use Mix.Task

  import Mix.NervesHubCLI.Utils
  alias NervesHubCLI.API
  alias Mix.NervesHubCLI.Shell

  @shortdoc "Manages your NervesHub keys"

  @moduledoc """
  Manage your NervesHub keys.

  ## list

    mix nerves_hub.key list

  ### Command line options

    * `--local` - (Optional) Perform the operation only locally
      defaults to `false` which will perform both local and remote operations

  ## create

  Create a new fwup key pair with the specified name.

    mix nerves_hub.key create [name]

  ### Command line options

    * `--local` - (Optional) Perform the operation only locally
      defaults to `false` which will perform both local and remote operations

  ## delete

  Delete the key with the specified name.

    mix nerves_hub.key create [name]

  ### Command line options

    * `--local` - (Optional) Perform the operation only locally
      defaults to `false` which will perform both local and remote operations
  """

  @switches [
    local: :boolean
  ]

  def run(args) do
    Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    case args do
      ["list"] ->
        list(opts)

      ["create", name] ->
        create(name, opts)

      ["delete", name] ->
        delete(name, opts)

      _ ->
        render_help()
    end
  end

  def render_help() do
    Shell.raise("""
    Invalid arguments

    Usage:
      mix nerves_hub.key list
      mix nerves_hub.key create [name]
      mix nerves_hub.key delete [name]
    """)
  end

  def list(opts) do
    if Keyword.get(opts, :local, false) do
      list_local()
    else
      list_remote()
    end
  end

  def list_local() do
    NervesHubCLI.Key.local_keys()
    |> Enum.map(&stringify/1)
    |> render_keys()
  end

  def list_remote() do
    auth = Shell.request_auth()

    case API.Key.list(auth) do
      {:ok, %{"data" => keys}} ->
        render_keys(keys)

      error ->
        Shell.info("Failed to list keys \nreason: #{inspect(error)}")
    end
  end

  def create(name, opts) do
    if NervesHubCLI.Key.exists?(name) do
      Shell.raise("The key #{name} already exists, aborting")
    else
      if Keyword.get(opts, :local, false) do
        with {:ok, key} <- create_local(name) do
          render_key(key)
        else
          error ->
            Shell.render_error(error)
        end
      else
        with {:ok, key} <- create_local(name),
             {:ok, %{"data" => key}} <- create_remote(name, key) do
          render_key(key)
        else
          error ->
            Shell.render_error(error)
        end
      end
    end
  end

  def delete(name, opts) do
    if Mix.shell().yes?("Delete Key #{name}?") do
      if Keyword.get(opts, :local, false) do
        delete_local(name)
      else
        with {:ok, ""} <- delete_remote(name),
             :ok <- delete_local(name) do
          :ok
        else
          error ->
            Shell.render_error(error)
        end
      end
    end
  end

  def delete_remote(name) do
    auth = Shell.request_auth()
    Shell.info("Deleting remote key #{name}")
    API.Key.delete(name, auth)
  end

  # TODO handle file not found
  def delete_local(name) do
    Shell.info("Deleting local key #{name}")
    NervesHubCLI.Key.delete(name)
  end

  defp create_local(name) do
    Shell.info("\nPlease enter a local password you wish to use to encrypt private key")
    key_password = Shell.password_get("Local key password:")

    with {:ok, public_key_file, _private_key_file} = NervesHubCLI.Key.create(name, key_password),
         {:ok, public_key} <- File.read(public_key_file) do
      {:ok, public_key}
    end
  end

  defp create_remote(name, key) do
    auth = Shell.request_auth()
    API.Key.create(name, key, auth)
  end

  defp render_keys([]) do
    Shell.info("No keys have been created")
  end

  defp render_keys(keys) when is_list(keys) do
    Shell.info("\nKeys:")

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
      name:  #{params["name"]}
      key:   #{params["key"]}
    """
  end
end

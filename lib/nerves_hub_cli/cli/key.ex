defmodule NervesHubCLI.CLI.Key do
  import NervesHubCLI.CLI.Utils

  alias NervesHubCLI.CLI.Shell

  @moduledoc """
  Manages firmware signing keys

  Firmware signing keys consist of public and private keys. The `nerves_hub key` 
  task manages both pieces for you. Private signing keys are password-protected 
  and are NEVER sent to NervesHub or any other server. Public keys, however, are 
  registered with NervesHub and embedded in your firmware.

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

      nerves_hub key list

  ### Command-line options

    * `--local` - (Optional) Do not request key information from NervesHub

  ## create

  Create a new firmware signing key pair with the specified name and register
  the public key with NervesHub

      nerves_hub key create NAME

  ### Command-line options

    * `--local` - (Optional) Do not register the public key with NervesHub

  ## delete

  Delete a signing key locally and on NervesHub

      nerves_hub key delete NAME

  ### Command-line options

    * `--local` - (Optional) Perform the operation only locally defaults to
      `false` which will perform both local and remote operations

  ## import

  Import an existing key locally and on NervesHub

      nerves_hub key import NAME PUBLIC_KEY_FILE PRIVATE_KEY_FILE

  ### Command-line options

    * `--local` - (Optional) Do not register the public key with NervesHub

  ## export

  Export a signing key to a tar.gz archive.

      nerves_hub key export NAME

  ### Command-line options

    * `--path` - (Optional) A local location for exporting keys.
  """

  @switches [
    org: :string,
    path: :string,
    local: :boolean
  ]

  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)

    show_api_endpoint()
    org = org(opts)

    case args do
      ["list"] ->
        list(org, opts)

      ["create", name] ->
        create(name, org, opts)

      ["delete", name] ->
        delete(name, org, opts)

      ["import", name, public_key_file, private_key_file] ->
        import(name, org, public_key_file, private_key_file, opts)

      ["export", name] ->
        export(name, org, opts)

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.raise("""
    Invalid arguments to `nerves_hub key`.

    Usage:
      nerves_hub key list
      nerves_hub key create NAME
      nerves_hub key delete NAME
      nerves_hub key import NAME PUBLIC_KEY_FILE PRIVATE_KEY_FILE
      nerves_hub key export NAME

    Run `nerves_hub help key` for more information.
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

    case NervesHubCLI.API.Key.list(org, auth) do
      {:ok, %{"data" => keys}} ->
        render_keys(keys)

      error ->
        Shell.info("Failed to list signing keys \nreason: #{inspect(error)}")
    end
  end

  def create(name, org, opts) do
    if NervesHubCLI.Key.exists?(org, name) do
      Shell.raise("""
      The key '#{name}' already exists.

      Please choose a different name or delete by
      running `nerves_hub key delete #{name} [--local]`
      """)
    else
      if Keyword.get(opts, :local, false) do
        with {:ok, key} <- create_local(name, org) do
          Shell.info("\nSuccess. Key information:")
          render_key(%{"name" => name, "key" => key})
        else
          error ->
            Shell.render_error(error)
        end
      else
        with {:ok, key} <- create_local(name, org),
             {:ok, %{"data" => key}} <- create_remote(name, key, org) do
          Shell.info("\nSuccess. Key information:")
          render_key(key)
        else
          error ->
            Shell.render_error(error)
        end
      end
    end
  end

  def delete(name, org, opts) do
    if Shell.yes?("Delete signing key '#{name}'?") do
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

  def import(name, org, public_key_file, private_key_file, opts) do
    if NervesHubCLI.Key.exists?(org, name) do
      Shell.raise("The key #{name} already exists, aborting")
    else
      if Keyword.get(opts, :local, false) do
        with {:ok, key} <- import_local(name, org, public_key_file, private_key_file) do
          Shell.info("\nSuccess. Key information:")
          render_key(%{"name" => name, "key" => key})
        else
          error ->
            Shell.render_error(error)
        end
      else
        with {:ok, key} <- import_local(name, org, public_key_file, private_key_file),
             {:ok, %{"data" => key}} <- create_remote(name, key, org) do
          Shell.info("\nSuccess. Key information:")
          render_key(key)
        else
          error ->
            Shell.render_error(error)
        end
      end
    end
  end

  def export(key, org, opts) do
    path = opts[:path] || NervesHubCLI.home_dir()

    with :ok <- File.mkdir_p(path),
         {:ok, public_key, private_key} <- Shell.request_keys(org, key),
         filename <- key_tar_file_name(path, org, key),
         {:ok, tar} <- :erl_tar.open(to_charlist(filename), [:write, :compressed]),
         :ok <- :erl_tar.add(tar, {~c"#{key}.pub", public_key}, []),
         :ok <- :erl_tar.add(tar, {~c"#{key}.priv", private_key}, []),
         :ok <- :erl_tar.close(tar) do
      Shell.info("Fwup keys exported to: #{filename}")
    else
      error -> Shell.render_error(error)
    end
  end

  def delete_remote(name, org) do
    auth = Shell.request_auth()
    Shell.info("Deleting signing key '#{name}' from NervesHub")
    NervesHubCLI.API.Key.delete(org, name, auth)
  end

  # TODO handle file not found
  def delete_local(name, org) do
    Shell.info("Deleting signing key '#{name}' locally")
    NervesHubCLI.Key.delete(org, name)
  end

  defp create_local(name, org) do
    Shell.info("Creating a firmware signing key pair named '#{name}'.")
    Shell.info("")
    Shell.info("The private key is stored locally and must be protected by a password.")
    Shell.info("If you are sharing the firmware signing private key with others,")
    Shell.info("please choose an appropriate password.")
    Shell.info("")
    key_password = Shell.password_get("Signing key password for '#{name}':")

    with {:ok, public_key_file, private_key_file} =
           NervesHubCLI.Key.create(org, name, key_password),
         {:ok, public_key} <- File.read(public_key_file) do
      Shell.info("")
      Shell.info("Firmware public key written to '#{public_key_file}'.")
      Shell.info("Password-protected firmware private key written to '#{private_key_file}'.")
      {:ok, public_key}
    end
  end

  defp create_remote(name, key, org) do
    Shell.info("\nRegistering the firmware signing public key '#{name}' with NervesHub.")
    auth = Shell.request_auth()
    NervesHubCLI.API.Key.create(org, name, key, auth)
  end

  defp import_local(name, org, public_key_file, private_key_file) do
    Shell.info("\nPlease enter a password to protect the firmware signing private key.")
    key_password = Shell.password_get("Signing key password for '#{name}':")

    with {:ok, public_key_file, _private_key_file} =
           NervesHubCLI.Key.import(org, name, key_password, public_key_file, private_key_file),
         {:ok, public_key} <- File.read(public_key_file) do
      {:ok, public_key}
    end
  end

  defp render_keys([]) do
    Shell.info("No firmware signing keys have been created.")
  end

  defp render_keys(keys) when is_list(keys) do
    Shell.info("\nFirmware signing keys:")

    Enum.each(keys, fn params ->
      Shell.info("------------")

      render_key(params)
    end)

    Shell.info("------------")
    Shell.info("")
  end

  defp render_key(params) do
    Shell.info("  name:       #{params["name"]}")
    Shell.info("  public key: #{params["key"]}")
  end

  defp key_tar_file_name(path, org, key),
    do: Path.join(path, "nerves_hub-fwup-keys-#{org}-#{key}.tar.gz")
end

defmodule Mix.Tasks.NervesHub.Device do
  use Mix.Task

  import Mix.NervesHubCLI.Utils
  alias NervesHubCLI.API
  alias Mix.NervesHubCLI.Shell

  @shortdoc "Manages your NervesHub devices"

  @moduledoc """
  Manage your NervesHub devices.

  ## create

  Create a new NervesHub device. The shell will prompt for information about the
  device. This information can be passed by specifying one or all of the command
  line options.

    mix nerves_hub.device create

  ### Command line options

    * `--identifier` - (Optional) The device identifier
    * `--description` - (Optional) The description of the device
    * `--tag` - (Optional) Multiple tags can be set by passing this key multiple
      times

  ## update

  Update values on a device.

  ### Examples

  Update device tags

    mix nerves_hub.device update 1234 tags dev qa

  ## burn

  Combine a firmware image with NervesHub provisioning information and burn the
  result to an attached MicroSD card or file. This requires that the device
  was already created. Calling burn without passing command line options will
  generate a new cert pair for the device. The command will end with calling
  mix firmware.burn.

    mix nerves_hub.device burn DEVICE_IDENTIFIER

  ### Command line options

    * `--cert` - (Optional) A path to an existing device certificate
    * `--key` - (Optional) A path to an existing device private key
    * `--path` - (Optional) The path to put the device certificates

  ## cert list

  List all certificates for a device.

    mix nerves_hub.device cert list DEVICE_IDENTIFIER

  ## cert create

  Creates a new device certificate pair. The certificates will be placed in the
  current working directory if no path is specified.

    mix nerves_hub.device cert create DEVICE_IDENTIFIER

  ### Command line options

    * `--path` - (Optional) A local location for storing certificates

  """

  @switches [
    org: :string,
    path: :string,
    identifier: :string,
    description: :string,
    tag: :keep,
    key: :string,
    cert: :string
  ]

  @data_dir "nerves-hub"

  def run(args) do
    Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    org = org(opts)

    case args do
      ["create"] ->
        create(org, opts)

      ["burn", identifier] ->
        burn(identifier, opts)

      ["cert", "list", device] ->
        cert_list(org, device)

      ["cert", "create", device] ->
        cert_create(org, device, opts)

      ["update", identifier | update_data] ->
        update(org, identifier, update_data)

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.raise("""
    Invalid arguments to `mix nerves_hub.device`.

    Usage:
      mix nerves_hub.device create
      mix nerves_hub.device update KEY VALUE
      mix nerves_hub.device burn DEVICE_IDENTIFIER
      mix nerves_hub.device cert list DEVICE_IDENTIFIER
      mix nerves_hub.device cert create DEVICE_IDENTIFIER

    Run `mix help nerves_hub.deployment` for more information.
    """)
  end

  def create(org, opts) do
    identifier = opts[:identifier] || Shell.prompt("identifier:")
    description = opts[:description] || Shell.prompt("description:")
    tags = Keyword.get_values(opts, :tag)

    tags =
      if tags == [] do
        Shell.prompt("tags:")
        |> String.split()
      else
        tags
      end

    auth = Shell.request_auth()

    case API.Device.create(org, identifier, description, tags, auth) do
      {:ok, %{"data" => %{} = _device}} ->
        Shell.info("Device #{identifier} created")

        if Shell.yes?("Would you like to generate certificates?") do
          cert_create(org, identifier, opts, auth)
        end

      error ->
        Shell.render_error(error)
    end
  end

  def update(org, identifier, ["tags" | tags]) do
    auth = Shell.request_auth()

    case API.Device.update(org, identifier, %{tags: tags}, auth) do
      {:ok, %{"data" => %{} = _device}} ->
        Shell.info("Device #{identifier} updated")

      error ->
        Shell.render_error(error)
    end
  end

  def update(org, identifier, [key, value]) do
    auth = Shell.request_auth()

    case API.Device.update(org, identifier, %{key => value}, auth) do
      {:ok, %{"data" => %{} = _device}} ->
        Shell.info("Device #{identifier} updated")

      error ->
        Shell.render_error(error)
    end
  end

  def update(_org, _identifier, data) do
    Shell.render_error("Unable to update data: #{inspect(data)}")
  end

  def burn(identifier, opts) do
    path = opts[:path] || Path.join(File.cwd!(), @data_dir)
    cert_path = opts[:cert]
    key_path = opts[:key]

    {cert_path, key_path} =
      if key_path == nil and cert_path == nil do
        cert_path = Path.join(path, identifier <> "-cert.pem")
        key_path = Path.join(path, identifier <> "-key.pem")

        unless File.exists?(key_path) and File.exists?(cert_path) do
          Shell.raise("""
            A private key and certificate for #{identifier}
            does not exists at path #{path}.

            To generate certificates for #{identifier}

              mix nerves_hub.device cert create #{identifier}

          """)
        end

        {cert_path, key_path}
      else
        if key_path == nil or cert_path == nil do
          Shell.raise("Must specify both --key and --cert")
        end

        {cert_path, key_path}
      end

    Shell.info("Burning firmware")
    System.put_env("NERVES_SERIAL_NUMBER", identifier)
    System.put_env("NERVES_HUB_CERT", File.read!(cert_path))
    System.put_env("NERVES_HUB_KEY", File.read!(key_path))
    Mix.Task.run("burn", [])
  end

  def cert_list(org, identifier) do
    auth = Shell.request_auth()

    case API.Device.cert_list(org, identifier, auth) do
      {:ok, %{"data" => certs}} ->
        render_certs(identifier, certs)

      error ->
        Shell.render_error(error)
    end
  end

  def cert_create(org, identifier, opts, auth \\ nil) do
    Shell.info("Creating certificate for #{identifier}")
    path = opts[:path] || Path.join(File.cwd!(), @data_dir)
    File.mkdir_p(path)
    auth = auth || Shell.request_auth()

    key = X509.PrivateKey.new_ec(:secp256r1)
    pem_key = X509.PrivateKey.to_pem(key)

    csr = X509.CSR.new(key, "/O=#{org}/CN=#{identifier}")
    pem_csr = X509.CSR.to_pem(csr)

    with safe_csr <- Base.encode64(pem_csr),
         {:ok, %{"data" => %{"cert" => cert}}} <-
           API.Device.cert_sign(org, identifier, safe_csr, auth),
         :ok <- File.write(Path.join(path, "#{identifier}-cert.pem"), cert),
         :ok <- File.write(Path.join(path, "#{identifier}-key.pem"), pem_key) do
      Shell.info("Finished")
      :ok
    else
      error ->
        Shell.render_error(error)
    end
  end

  defp render_certs(identifier, certs) when is_list(certs) do
    Shell.info("\nDevice: #{identifier}")
    Shell.info("Certificates:")

    Enum.each(certs, fn params ->
      Shell.info("------------")

      render_certs(identifier, params)
      |> String.trim_trailing()
      |> Shell.info()
    end)

    Shell.info("------------")
    Shell.info("")
  end

  defp render_certs(_identifier, params) do
    {:ok, not_before, _} = DateTime.from_iso8601(params["not_before"])

    {:ok, not_after, _} = DateTime.from_iso8601(params["not_after"])

    """
      serial:     #{params["serial"]}
      validity:   #{DateTime.to_date(not_before)} - #{DateTime.to_date(not_after)} UTC
    """
  end
end

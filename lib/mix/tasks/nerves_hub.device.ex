defmodule Mix.Tasks.NervesHub.Device do
  use Mix.Task

  import Mix.NervesHubCLI.Utils

  alias Mix.NervesHubCLI.{Shell, Bulk}

  alias NimbleCSV.RFC4180, as: CSV

  @shortdoc "Manages your NervesHub devices"

  @moduledoc """
  Manage your NervesHub devices.

  ## create

  Create a new NervesHub device. The shell will prompt for information about the
  device. This information can be passed by specifying one or all of the command
  line options.

      mix nerves_hub.device create

  ### Command-line options

    * `--product` - (Optional) The product name.
      This defaults to the Mix Project config `:app` name.
    * `--identifier` - (Optional) The device identifier
    * `--description` - (Optional) The description of the device
    * `--tag` - (Optional) Multiple tags can be set by passing this key multiple
      times

  ## bulk_create

  Create many NervesHub devices via a csv file.

      mix nerves_hub.device bulk_create

  The CSV file should be formated as:
  ```csv
  identifier,tags,description
  ```

  Where `tags` is a double-quoted string, containing comma delimited tags.

  ### Example CSV file:

  ```csv
  identifier,tags,description
  00000000d712d174,"tag1,tag2,tag3",some useful description of the device
  00000000deadb33f,"qa,region1",this device should only be used with QA
  ```

  ### Command-line options

    * `--csv` - Path to a CSV file

    * `--product` - (Optional) The product name.
      This defaults to the Mix Project config `:app` name.

  ## update

  Update values on a device.

  ### Examples

  List all devices

      mix nerves_hub.device list

  ### Command-line options

  * `--product` - (Optional) The product name.
      This defaults to the Mix Project config `:app` name.
  * `--identifier` - (Optional) Only show device matching an identifier
  * `--description` - (Optional) Only show devices matching a description
  * `--tag` - (Optional) Only show devices matching tags. Multiple tags can be
  supplied.
  * `--status` - (Optional) Only show devices matching status
  * `--version` - (Optional) Only show devices matching version


  Update device tags

      mix nerves_hub.device update 1234 tags dev qa

  ## delete

  Delete a device on NervesHub

      mix nerves_hub.device delete DEVICE_IDENTIFIER

  ## burn

  Combine a firmware image with NervesHub provisioning information and burn the
  result to an attached MicroSD card or file. This requires that the device
  was already created. Calling burn without passing command-line options will
  generate a new cert pair for the device. The command will end with calling
  mix firmware.burn.

      mix nerves_hub.device burn DEVICE_IDENTIFIER

  ### Command-line options

    * `--product` - (Optional) The product name.
      This defaults to the Mix Project config `:app` name.
    * `--cert` - (Optional) A path to an existing device certificate
    * `--key` - (Optional) A path to an existing device private key
    * `--path` - (Optional) The path to put the device certificates
    * `--firmware` - (Optional) The path to the fw file to use. Defaults to
      `<image_path>/<otp_app>.fw`

  ## cert list

  List all certificates for a device.

      mix nerves_hub.device cert list DEVICE_IDENTIFIER

  ### Command-line options

    * `--product` - (Optional) The product name.
      This defaults to the Mix Project config `:app` name.

  ## cert create

  Creates a new device certificate pair. The certificates will be placed in the
  current working directory if no path is specified.

      mix nerves_hub.device cert create DEVICE_IDENTIFIER

  By default, this will send a certificate signing request to be signed by
  NervesHubCA (or other specified CA used with NervesHub if hosting your own).

  You can also take on the role of the CA by providing your own signer
  certificate and key and using the `--signer-cert` and `--signer-key` options.
  These will be used with a NervesHub-defined certificate template to sign the
  generated device certificate locally

  ### Command-line options

    * `--product` - (Optional) The product name.
      This defaults to the Mix Project config `:app` name.
    * `--path` - (Optional) A local location for storing certificates
    * `--signer-cert` - (Optional) Path to the signer certificate (requires `--signer-key`)
    * `--signer-key` - (Optional) Path to signer certificate's private key (requires `--signer-cert`)
    * `--validity` - (Optional) Time in years a certificate should be valid.
      Only used with `--signer-cert` and `--signer-key` options. Defaults to 31.

  ## cert import

  Import a trusted certificate for authenticating a device.

      mix nerves_hub.device cert import DEVICE_IDENTIFIER CERT_PATH

  ### Command-line options

    * `--product` - (Optional) The product name.
      This defaults to the Mix Project config `:app` name.
  """

  @switches [
    org: :string,
    product: :string,
    path: :string,
    identifier: :string,
    description: :string,
    firmware: :string,
    tag: :keep,
    key: :string,
    cert: :string,

    # Options for local cert creation
    signer_cert: :string,
    signer_key: :string,
    validity: :integer,

    # device list filters
    status: :string,
    version: :string,

    # device bulk_create
    csv: :string
  ]

  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    # compile the project in case we need CA certs from it
    _ = Mix.Task.run("compile")
    _ = Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    show_api_endpoint()
    org = org(opts)
    product = product(opts)

    case args do
      ["list"] ->
        list(org, product, opts)

      ["create"] ->
        create(org, product, opts)

      ["bulk_create"] ->
        bulk_create(org, product, opts)

      ["delete", identifier] ->
        delete(org, product, identifier)

      ["burn", identifier] ->
        burn(identifier, opts)

      ["cert", "list", device] ->
        cert_list(org, product, device)

      ["cert", "create", device] ->
        cert_create(org, product, device, opts)

      ["cert", "import", device, cert_path] ->
        cert_import(org, product, device, cert_path, opts)

      ["update", identifier | update_data] ->
        update(org, product, identifier, update_data)

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.raise("""
    Invalid arguments to `mix nerves_hub.device`.

    Usage:
      mix nerves_hub.device list
      mix nerves_hub.device create
      mix nerves_hub.device update KEY VALUE
      mix nerves_hub.device delete DEVICE_IDENTIFIER
      mix nerves_hub.device burn DEVICE_IDENTIFIER
      mix nerves_hub.device cert list DEVICE_IDENTIFIER
      mix nerves_hub.device cert create DEVICE_IDENTIFIER
      mix nerves_hub.device cert import DEVICE_IDENTIFIER CERT_PATH

    Run `mix help nerves_hub.device` for more information.
    """)
  end

  @spec list(String.t(), String.t(), keyword()) :: :ok
  def list(org, product, opts) do
    auth = Shell.request_auth()

    case NervesHubUserAPI.Device.list(org, product, auth) do
      {:ok, %{"data" => devices}} ->
        filetered_devices = Enum.filter(devices, &filter_devices(&1, opts))
        Shell.info(render_devices(org, product, filetered_devices))
        Shell.info("Total devices displayed: #{Enum.count(filetered_devices)}")
        Shell.info("Total devices: #{Enum.count(devices)}")

      error ->
        Shell.render_error(error)
    end
  end

  @spec create(String.t(), String.t(), keyword()) :: :ok
  def create(org, product, opts) do
    identifier = opts[:identifier] || Shell.prompt("Identifier (e.g., serial number):")
    description = opts[:description] || Shell.prompt("Description:")

    # Tags may be specified using multiple `--tag` options or as `--tag "a, b, c"`
    tags = Keyword.get_values(opts, :tag) |> Enum.flat_map(&split_tag_string/1)

    tags =
      if tags == [] do
        Shell.prompt("One or more comma-separated tags:")
        |> split_tag_string()
      else
        tags
      end

    auth = Shell.request_auth()

    case NervesHubUserAPI.Device.create(org, product, identifier, description, tags, auth) do
      {:ok, %{"data" => %{} = _device}} ->
        Shell.info("""
        Device #{identifier} created.

        If your device has an ATECCx08A module or NervesKey that has been
        provisioned by a CA/signer certificate known to NervesHub, it is
        ready to go.

        If not using a hardware module to protect the device's private
        key, create and register a certificate and key pair manually by
        running:

          mix nerves_hub.device cert create #{identifier}
        """)

      error ->
        Shell.render_error(error)
    end
  end

  @spec bulk_create(String.t(), String.t(), keyword()) :: :ok
  def bulk_create(org, product, args) do
    auth = Shell.request_auth()
    path = args[:csv]

    unless is_bitstring(path) do
      Shell.render_error({:error, "--csv is required for bulk_create"})
    end

    unless File.exists?(path) do
      Shell.render_error({:error, "CSV file not found"})
    end

    File.stream!(path)
    |> CSV.parse_stream()
    |> Enum.to_list()
    |> Bulk.create_devices(org, product, auth)
    |> Bulk.display_results(path)
  end

  @spec update(String.t(), String.t(), String.t(), [String.t()]) :: :ok
  def update(org, product, identifier, ["tags" | tags]) do
    # Split up tags with comma separators
    tags = Enum.flat_map(tags, &split_tag_string/1)

    auth = Shell.request_auth()

    case NervesHubUserAPI.Device.update(org, product, identifier, %{tags: tags}, auth) do
      {:ok, %{"data" => %{} = _device}} ->
        Shell.info("Device #{identifier} updated")

      error ->
        Shell.render_error(error)
    end
  end

  def update(org, product, identifier, [key, value]) do
    auth = Shell.request_auth()

    case NervesHubUserAPI.Device.update(org, product, identifier, %{key => value}, auth) do
      {:ok, %{"data" => %{} = _device}} ->
        Shell.info("Device #{identifier} updated")

      error ->
        Shell.render_error(error)
    end
  end

  def update(_org, _product, _identifier, data) do
    Shell.render_error("Unable to update data: #{inspect(data)}")
  end

  @spec delete(String.t(), String.t(), String.t()) :: :ok
  def delete(org, product, identifier) do
    auth = Shell.request_auth()

    case NervesHubUserAPI.Device.delete(org, product, identifier, auth) do
      {:ok, _} ->
        Shell.info("Device #{identifier} deleted")

      error ->
        Shell.render_error(error)
    end
  end

  @spec burn(String.t(), keyword()) :: :ok
  def burn(identifier, opts) do
    path = opts[:path] || NervesHubCLI.home_dir()
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

    burn_args =
      opts
      |> Keyword.take([:firmware])
      |> OptionParser.to_argv()

    Mix.Task.run("burn", burn_args)
  end

  @spec cert_list(String.t(), String.t(), String.t()) :: :ok
  def cert_list(org, product, identifier) do
    auth = Shell.request_auth()

    case NervesHubUserAPI.DeviceCertificate.list(org, product, identifier, auth) do
      {:ok, %{"data" => certs}} ->
        render_certs(identifier, certs)

      error ->
        Shell.render_error(error)
    end
  end

  @spec cert_create(
          String.t(),
          String.t(),
          String.t(),
          keyword(),
          nil | NervesHubUserAPI.Auth.t()
        ) :: :ok
  def cert_create(org, product, identifier, opts, auth \\ nil) do
    Shell.info("Creating certificate for #{identifier}")
    path = opts[:path] || NervesHubCLI.home_dir()
    File.mkdir_p!(path)

    key = X509.PrivateKey.new_ec(:secp256r1)
    pem_key = X509.PrivateKey.to_pem(key)

    csr = X509.CSR.new(key, "/O=#{org}/CN=#{identifier}")

    create_args =
      if opts[:signer_cert] && opts[:signer_key] do
        # create cert locally with provided signer
        {csr, opts}
      else
        # request cert from NervesHub
        {org, product, identifier, csr, auth}
      end

    with {:ok, cert} <- do_cert_create(create_args),
         :ok <- File.write(Path.join(path, "#{identifier}-cert.pem"), cert),
         :ok <- File.write(Path.join(path, "#{identifier}-key.pem"), pem_key) do
      Shell.info("Finished")
      :ok
    else
      error ->
        Shell.render_error(error)
    end
  end

  @spec cert_import(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          keyword()
        ) :: :ok
  def cert_import(org, product, identifier, cert_path, _opts) do
    Shell.info("Importing certificate for #{identifier}")

    with {:ok, cert_pem} <- File.read(cert_path),
         auth <- Shell.request_auth(),
         {:ok, %{"data" => %{"serial" => serial}}} <-
           NervesHubUserAPI.DeviceCertificate.create(org, product, identifier, cert_pem, auth) do
      Shell.info("Device certificate '#{serial_as_hex(serial)}' registered.")
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
      serial hex: #{serial_as_hex(params["serial"])}
      validity:   #{DateTime.to_date(not_before)} - #{DateTime.to_date(not_after)} UTC
    """
  end

  defp render_devices(_org, _product, []), do: ""

  defp render_devices(org, product, devices) do
    title = "Devices for #{org} / #{product}"

    header = [
      "Identifier",
      "Tags",
      "Version",
      "Firmware UUID",
      "Status",
      "Last connected",
      "Description"
    ]

    rows =
      Enum.map(devices, fn device ->
        [
          device["identifier"],
          Enum.join(device["tags"] || [], ", "),
          device["version"],
          device["firmware_metadata"]["uuid"],
          device["status"],
          device["last_communication"],
          device["description"]
        ]
      end)

    TableRex.quick_render!(rows, header, title)
  end

  defp filter_devices(device, [{:status, val} | rest]) do
    if device["status"] == val, do: filter_devices(device, rest)
  end

  defp filter_devices(device, [{:version, version} | rest]) do
    if device["version"] == version, do: filter_devices(device, rest)
  end

  defp filter_devices(device, [{:tag, tag} | rest]) do
    tags = device["tags"] || []

    if Enum.any?(tags, fn device_tag -> device_tag == tag end),
      do: filter_devices(device, rest)
  end

  defp filter_devices(device, [{:identifier, identifier} | rest]) do
    if device["identifier"] == identifier, do: filter_devices(device, rest)
  end

  defp filter_devices(device, [{:description, description} | rest]) do
    if device["description"] == description, do: filter_devices(device, rest)
  end

  defp filter_devices(device, [_ | rest]) do
    filter_devices(device, rest)
  end

  defp filter_devices(device, []), do: device

  defp do_cert_create({csr, opts}) do
    Shell.info("Signer cert path: #{opts[:signer_cert]}")
    Shell.info("Signer key path: #{opts[:signer_key]}")

    with {:ok, signer_cert_pem} <- File.read(opts[:signer_cert]),
         {:ok, signer_key_pem} <- File.read(opts[:signer_key]),
         {:ok, signer_cert} <- X509.Certificate.from_pem(signer_cert_pem),
         {:ok, signer_key} <- X509.PrivateKey.from_pem(signer_key_pem) do
      subject_rdn = X509.CSR.subject(csr) |> X509.RDNSequence.to_string()
      public_key = X509.CSR.public_key(csr)

      cert =
        X509.Certificate.new(public_key, subject_rdn, signer_cert, signer_key,
          template: NervesHubCLI.Certificate.device_template(opts[:validity])
        )

      {:ok, X509.Certificate.to_pem(cert)}
    end
  end

  defp do_cert_create({org, product, id, csr, auth}) do
    auth = auth || Shell.request_auth()
    pem_csr = X509.CSR.to_pem(csr)

    with safe_csr <- Base.encode64(pem_csr),
         {:ok, %{"data" => %{"cert" => cert}}} <-
           NervesHubUserAPI.DeviceCertificate.sign(org, product, id, safe_csr, auth) do
      {:ok, cert}
    end
  end
end

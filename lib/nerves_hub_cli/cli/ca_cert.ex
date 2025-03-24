defmodule NervesHubCLI.CLI.CACert do
  import NervesHubCLI.CLI.Utils

  @moduledoc """
  Manages CA certificates for validating device connections

  When a device connects for the first time to NervesHub, it's possible to automatically
  register it if its certificate has been signed by a trusted CA certificate.

  This set of utilities helps manage the trusted CA certificates.

  # Available commands

    - `list`         List CA Certificates
    - `register`     Register a CA Certificate with an Organization
    - `unregister`   Remove a CA Certificate from an Organization


  ## List CA Certificates

  List all CA certificates registered with an organization.

  Usage:

      $ nh cacert list


  ## Register a CA Certificate

  Register a CA Certificate with an Organization.

  Required arguments:

    - `CERT_PATH` - path to the CA certificate file

  Usage:

      $ nh cacert register CERT_PATH


  ## Unregister a CA Certificate

  Remove a CA Certificate from an Organization.

  Required arguments:

  - `CERT_SERIAL` : The serial of the CA certificate

  Usage:
      $ nh cacert unregister CERT_SERIAL
  """

  alias NervesHubCLI.CLI.Shell

  @switches [
    org: :string,
    description: :string
  ]

  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)

    case args do
      ["list"] ->
        list(opts)

      ["register", certificate_path] ->
        register(certificate_path, opts)

      ["unregister", serial] ->
        unregister(serial, opts)

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
    Shell.unrecognized_command(unrecognized_command, "cacert")
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.module_help("CA Certificates", @moduledoc)
  end

  def list(opts) do
    {auth, org} = common_api_requirements(opts)

    case NervesHubCLI.API.CACertificate.list(org, auth) do
      {:ok, %{"data" => ca_certificates}} ->
        render_ca_certificates(ca_certificates)

      error ->
        Shell.error("\nFailed to list CA certificates")
        Shell.info("\nReason: #{inspect(error)}")
    end
  end

  def register(cert_path, opts \\ []) do
    {auth, org} = common_api_requirements(opts)

    with {:ok, cert_pem} <- File.read(cert_path),
         description <- Keyword.get(opts, :description),
         {:ok, %{"data" => %{"serial" => serial}}} <-
           NervesHubCLI.API.CACertificate.create(org, cert_pem, auth, description) do
      Shell.info("CA certificate '#{serial_as_hex(serial)}' registered.")
    else
      error ->
        Shell.render_error(error)
    end
  end

  def unregister(serial, opts) do
    {auth, org} = common_api_requirements(opts)

    if Shell.yes?("Unregister CA certificate '#{serial}'?") do
      Shell.info("Unregistering CA certificate '#{serial}'")

      serial = if String.contains?(serial, ":"), do: serial_from_hex(serial), else: serial

      case NervesHubCLI.API.CACertificate.delete(org, serial, auth) do
        {:ok, ""} ->
          Shell.info("CA certificate unregistered successfully")

        error ->
          Shell.render_error(error)
      end
    end
  end

  defp common_api_requirements(opts) do
    show_api_endpoint()
    auth = Shell.request_auth()
    org = org(opts)
    {auth, org}
  end

  defp render_ca_certificates([]) do
    Shell.info([:blue, "\nNo CA Certificates registered.\n"])
  end

  defp render_ca_certificates(ca_certificates) when is_list(ca_certificates) do
    Shell.info("\nCA Certificates:")

    Enum.each(ca_certificates, fn params ->
      Shell.info("------------")

      render_ca_certificate(params)
      |> String.trim_trailing()
      |> Shell.info()
    end)

    Shell.info("------------")
    Shell.info("")
  end

  defp render_ca_certificate(params) do
    {:ok, not_before, _} = DateTime.from_iso8601(params["not_before"])
    {:ok, not_after, _} = DateTime.from_iso8601(params["not_after"])

    """
      serial:      #{params["serial"]}
      serial hex:  #{serial_as_hex(params["serial"])}
      validity:    #{DateTime.to_date(not_before)} - #{DateTime.to_date(not_after)} UTC
      description: #{params["description"]}
    """
  end

  defp serial_from_hex(hex) do
    String.replace(hex, ":", "")
    |> String.to_integer(16)
    |> to_string()
  end
end

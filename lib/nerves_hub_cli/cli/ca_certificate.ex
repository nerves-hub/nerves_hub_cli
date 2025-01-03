defmodule NervesHubCLI.CLI.CaCertificate do
  import NervesHubCLI.CLI.Utils
  alias NervesHubCLI.CLI.Shell

  @moduledoc """
  Manages CA certificates for validating device connections

  When a device connects for the first time to NervesHub, it
  is possible to automatically register it if its certificate
  has been signed by a trusted CA certificate. This set of
  utilities helps manage the trusted CA certificates.

  ## list

      nerves_hub ca_certificate list

  ## register

      nerves_hub ca_certificate register CERT_PATH

  ## unregister

      nerves_hub ca_certificate unregister CERT_SERIAL
  """

  @switches [
    org: :string,
    description: :string
  ]

  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)

    show_api_endpoint()
    org = org(opts)

    case args do
      ["list"] ->
        list(org)

      ["register", certificate_path] ->
        register(certificate_path, org, opts)

      ["unregister", serial] ->
        unregister(serial, org)

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.raise("""
    Invalid arguments to `nerves_hub ca_certificate`.

    Usage:
      nerves_hub ca_certificate list
      nerves_hub ca_certificate register CERT_PATH
      nerves_hub ca_certificate unregister CERT_SERIAL

    Run `nerves_hub help ca_certificate` for more information.
    """)
  end

  def list(org) do
    auth = Shell.request_auth()

    case NervesHubCLI.API.CACertificate.list(org, auth) do
      {:ok, %{"data" => ca_certificates}} ->
        render_ca_certificates(ca_certificates)

      error ->
        Shell.info("Failed to list CA certificates \nreason: #{inspect(error)}")
    end
  end

  def register(cert_path, org, opts \\ []) do
    with {:ok, cert_pem} <- File.read(cert_path),
         auth <- Shell.request_auth(),
         description <- Keyword.get(opts, :description),
         {:ok, %{"data" => %{"serial" => serial}}} <-
           NervesHubCLI.API.CACertificate.create(org, cert_pem, auth, description) do
      Shell.info("CA certificate '#{serial_as_hex(serial)}' registered.")
    else
      error ->
        Shell.render_error(error)
    end
  end

  def unregister(serial, org) do
    if Shell.yes?("Unregister CA certificate '#{serial}'?") do
      auth = Shell.request_auth()
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

  defp render_ca_certificates([]) do
    Shell.info("No CA certificates have been registered on NervesHub.")
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

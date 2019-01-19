defmodule Mix.Tasks.NervesHub.CaCertificate do
  use Mix.Task

  import Mix.NervesHubCLI.Utils
  alias Mix.NervesHubCLI.Shell

  @shortdoc "Manages CA certificates"

  @moduledoc """
  Manages CA certificates

  ## list

  mix nerves_hub.ca_certificate list

  ## create

  mix nerves_hub.ca_certificate create CERT_PATH

  ## delete

  mix nerves_hub.ca_certificate delete CERT_SERIAL
  """

  @switches [
    org: :string
  ]

  def run(args) do
    Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    show_api_endpoint()
    org = org(opts)

    case args do
      ["list"] ->
        list(org)

      ["create", certificate_path] ->
        create(certificate_path, org)

      ["delete", serial] ->
        delete(serial, org)

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.raise("""
    Invalid arguments to `mix nerves_hub.ca_certificate`.

    Usage:
      mix nerves_hub.ca_certificate list
      mix nerves_hub.ca_certificate create CERT_PATH
      mix nerves_hub.ca_certificate delete CERT_SERIAL

    Run `mix help nerves_hub.ca_certificate` for more information.
    """)
  end

  def list(org) do
    auth = Shell.request_auth()

    case NervesHubCore.CACertificate.list(org, auth) do
      {:ok, %{"data" => ca_certificates}} ->
        render_ca_certificates(ca_certificates)

      error ->
        Shell.info("Failed to list CA certificates \nreason: #{inspect(error)}")
    end
  end

  def create(cert_path, org) do
    with {:ok, cert_pem} <- File.read(cert_path),
         auth = Shell.request_auth(),
         {:ok, %{"data" => %{"serial" => serial}}} <-
           NervesHubCore.CACertificate.create(org, cert_pem, auth) do
      Shell.info("CA certificate '#{serial}' created.")
    else
      error ->
        Shell.render_error(error)
    end
  end

  def delete(serial, org) do
    if Shell.yes?("Delete CA certificate '#{serial}'?") do
      auth = Shell.request_auth()
      Shell.info("Deleting CA certificate '#{serial}'")

      case NervesHubCore.CACertificate.delete(org, serial, auth) do
        {:ok, ""} ->
          Shell.info("CA certificate deleted successfully")

        error ->
          Shell.render_error(error)
      end
    end
  end

  defp render_ca_certificates([]) do
    Shell.info("No CA certificates have been created.")
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
      serial:     #{params["serial"]}
      validity:   #{DateTime.to_date(not_before)} - #{DateTime.to_date(not_after)} UTC
    """
  end
end

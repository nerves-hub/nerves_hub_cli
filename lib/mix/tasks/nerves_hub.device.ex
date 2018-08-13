defmodule Mix.Tasks.NervesHub.Device do
  use Mix.Task

  alias NervesHubCLI.API
  alias Mix.NervesHubCLI.Shell

  @shortdoc "Manages your NervesHub devices"

  @moduledoc """
  Manage your NervesHub devices.

  """

  @switches [
    path: :string,
    identifier: :string,
    description: :string,
    tag: :keep
  ]

  def run(args) do
    Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    case args do
      ["create"] ->
        create(opts)

      ["cert", "list", device] ->
        cert_list(device)

      ["cert", "create", device] ->
        cert_create(device, opts)

      _ ->
        render_help()
    end
  end

  def render_help() do
    Shell.raise("""
    Invalid arguments

    Usage:
      mix nerves_hub.device create
      mix nerves_hub.device cert list [identifier]
      mix nerves_hub.device cert create [identifier]
    """)
  end

  def create(opts) do
    identifier = opts[:identifier] || Shell.prompt("identifier:")
    description = opts[:description] || Shell.prompt("description:")
    tags = Keyword.get_values(opts, :tag)
    tags = 
      if tags == [] do
        Shell.prompt("tags:")
        |> String.split(tags)
      else
        tags
      end
    
    auth = Shell.request_auth()

    case API.Device.create(identifier, description, tags, auth) do
      {:ok, %{"data" => %{} = _device}} ->
        Shell.info("Device #{identifier} created")

      error ->
        Shell.render_error(error)
    end
  end

  def cert_list(identifier) do
    auth = Shell.request_auth()

    case API.Device.cert_list(identifier, auth) do
      {:ok, %{"data" => certs}} ->
        render_certs(identifier, certs)

      error ->
        Shell.render_error(error)
    end
  end

  def cert_create(identifier, opts) do
    path = opts[:path] || File.cwd!
    auth = Shell.request_auth()
    with {:ok, csr} <- NervesHubCLI.Device.generate_csr(identifier, path),
         safe_csr <- Base.encode64(csr),
         {:ok, %{"data" => %{"cert" => cert}}} <- API.Device.cert_sign(identifier, safe_csr, auth),
         :ok <- File.write(Path.join(path, "#{identifier}-cert.pem"), cert) do
      Shell.info("Finished")
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
    {:ok, not_before, _} = 
      DateTime.from_iso8601(params["not_before"])
    
    {:ok, not_after, _} = 
      DateTime.from_iso8601(params["not_after"])

    """
      serial:     #{params["serial"]}
      validity:   #{DateTime.to_date(not_before)} - #{DateTime.to_date(not_after)} UTC
    """
  end
end

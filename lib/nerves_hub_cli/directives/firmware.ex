defmodule NervesHubCLI.Directives.Firmware do
  # @shortdoc "Manages firmware on NervesHub"

  @moduledoc """
  Manage Firmware on NervesHub

  ## publish

  Upload signed firmware to NervesHub. Supplying a path to the firmware file
  is optional. If it is not specified, NervesHub will locate the firmware
  based off the project settings.

      nh firmware publish [Optional: /path/to/app.firmware]

  ### Command-line options

    * `--product` - (Optional) The product name to publish the firmware to.
      This defaults to the Mix Project config `:app` name.
    * `--deploy` - (Optional) The name of a deployment to update following
      firmware publish. This key can be passed multiple times to update
      multiple deployments.
    * `--key` - (Optional) The firmware signing key to sign the firmware with.
    * `--ttl` - (Optional) The firmware max time to live seconds.

  ## list

      nh firmware list

  ### Command-line options

    * `--product` - (Optional) The product name to publish the firmware to.
      This defaults to the Mix Project config `:app` name.

  ## delete

  Firmware can only be deleted if it is not associated to any deployment.
  Call `list` to retrieve firmware UUIDs

      nh firmware delete [firmware_uuid]

  ## sign

  Sign the local firmware. Supplying a path to the firmware file
  is optional. If it is not specified, NervesHub will locate the firmware
  based off the project settings.

      nh firmware sign [Optional: /path/to/app.firmware]

  ### Command-line options

    * `--key` - (Optional) The firmware signing key to sign the firmware with.

  """

  import NervesHubCLI.Utils
  alias NervesHubCLI.Cmd
  alias NervesHubCLI.Shell

  @switches [
    org: :string,
    product: :string,
    deploy: :keep,
    key: :string,
    ttl: :integer
  ]

  def run(args) do
    _ = Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    show_api_endpoint()
    org = org(opts)
    product = product(opts)

    case args do
      ["list"] ->
        list(org, product)

      ["publish" | []] ->
        firmware()
        |> publish_confirm(org, opts)

      ["publish", firmware] when is_binary(firmware) ->
        firmware
        |> Path.expand()
        |> publish_confirm(org, opts)

      ["delete", uuid] when is_binary(uuid) ->
        delete_confirm(uuid, org, product)

      ["sign"] ->
        firmware()
        |> sign(org, opts)

      ["sign", firmware] ->
        sign(firmware, org, opts)

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.info("""
    Invalid arguments

    Usage:
      nh firmware list
      nh firmware publish
      nh firmware delete
      nh firmware sign


    """)
  end

  def list(org, product) do
    auth = Shell.request_auth()

    case NervesHubUserAPI.Firmware.list(org, product, auth) do
      {:ok, %{"data" => []}} ->
        Shell.info("No firmware has been published for product: #{product}")

      {:ok, %{"data" => firmwares}} ->
        Shell.info("")
        Shell.info("Firmwares:")

        Enum.each(firmwares, fn metadata ->
          Shell.info("------------")

          render_firmware(metadata)
          |> String.trim_trailing()
          |> Shell.info()
        end)

        Shell.info("")

      error ->
        Shell.render_error(error)
    end
  end

  defp publish_confirm(firmware, org, opts) do
    with true <- File.exists?(firmware),
         {:ok, metadata} <- metadata(firmware) do
      Shell.info("------------")
      Shell.info("Organization: #{org}")

      render_firmware(metadata)
      |> String.trim_trailing()
      |> Shell.info()

      if Shell.yes?("Publish Firmware?") do
        product = metadata["product"]
        publish(firmware, org, product, opts)
      end
    else
      false ->
        Shell.info("Cannot find firmware at #{firmware}")

      {:error, reason} ->
        Shell.info("Unable to parse firmware metadata: #{inspect(reason)}")
    end
  end

  defp delete_confirm(uuid, org, product) do
    Shell.info("UUID: #{uuid}")

    if Shell.yes?("Delete Firmware?") do
      delete(uuid, org, product)
    end
  end

  defp publish(firmware, org, product, opts) do
    if opts[:key] do
      sign(firmware, org, opts)
    end

    auth = Shell.request_auth()

    ttl = opts[:ttl]

    case NervesHubUserAPI.Firmware.create(org, product, firmware, ttl, auth) do
      {:ok, %{"data" => %{} = firmware}} ->
        Shell.info("\nFirmware published successfully")

        Keyword.get_values(opts, :deploy)
        |> maybe_deploy(firmware, org, product, auth)

      error ->
        Shell.render_error(error)
    end
  end

  defp delete(uuid, org, product) do
    auth = Shell.request_auth()

    case NervesHubUserAPI.Firmware.delete(org, product, uuid, auth) do
      {:ok, ""} ->
        Shell.info("Firmware deleted successfully")

      error ->
        Shell.render_error(error)
    end
  end

  def sign(firmware, org, opts) do
    key = opts[:key] || Shell.raise("Must specify key with --key")
    Shell.info("Signing #{firmware}")
    Shell.info("With key #{key}")

    with {:ok, public_key, private_key} <- Shell.request_keys(org, key),
         :ok <-
           Cmd.fwup(
             [
               "--sign",
               "-i",
               firmware,
               "-o",
               firmware,
               "--private-key",
               private_key,
               "--public-key",
               public_key
             ],
             File.cwd!()
           ) do
      Shell.info("Finished signing")
    else
      error -> Shell.render_error(error)
    end
  end

  defp maybe_deploy([], _, _, _, _), do: :ok

  defp maybe_deploy(deployments, firmware, org, product, auth) do
    Enum.each(deployments, fn deployment_name ->
      Shell.info("Deploying firmware to #{deployment_name}")

      NervesHubCLI.Directives.Deployment.update(
        deployment_name,
        "firmware",
        firmware["uuid"],
        org,
        product,
        auth
      )
    end)
  end

  defp render_firmware(params) do
    """
      product:      #{params["product"]}
      version:      #{params["version"]}
      platform:     #{params["platform"]}
      architecture: #{params["architecture"]}
      uuid:         #{params["uuid"]}
    """
  end
end

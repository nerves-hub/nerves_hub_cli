defmodule Mix.Tasks.NervesHub.Deployment do
  use Mix.Task

  @shortdoc "Manages NervesHub deployments"

  @moduledoc """
  Manage HervesHub deployments

  ## list

    mix nerves_hub.deployment list

  ### Command line options

    * `--product` - (Optional) The product name to list deployments for.
      This defaults to the Mix Project config `:app` name.

  ## update

  Update values on a deployment. 

  ### Examples

  Update active firmware version

    mix nerves_hub.deployment update dev firmware fd53d87c-99ca-5770-5540-edb5058ced5b

  Activate / Deactivate a deployment

    mix nerves_hub.deployment update dev is_active true

  General useage:

    mix nerves_hub.firmware update [deployment_name] [key] [value]

  """

  import Mix.NervesHubCLI.Utils
  alias NervesHubCLI.API
  alias Mix.NervesHubCLI.Shell

  @switches [
    product: :string
  ]

  def run(args) do
    Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    case args do
      ["list"] ->
        list(opts)

      ["update", deployment, key, value] ->
        update(deployment, key, value, opts)

      _ ->
        render_help()
    end
  end

  def render_help() do
    Shell.raise("""
    Invalid arguments

    Usage:
      mix nerves_hub.deployment list
      mix nerves_hub.deployment update [deployment_name] [key] [value]
    """)
  end

  def list(opts) do
    auth = Shell.request_auth()
    product = opts[:product] || default_product()
    case API.Deployment.list(product, auth) do
      {:ok, %{"data" => []}} ->
        Shell.info("No deployments have been created for product: #{product}")

      {:ok, %{"data" => deployments}} ->
        Shell.info("")
        Shell.info("Deployments:")

        Enum.each(deployments, fn params ->
          Shell.info("------------")

          render_deployment(params)
          |> String.trim_trailing()
          |> Shell.info()

          Shell.info("------------")
        end)

        Shell.info("")

      error ->
        Shell.info("Failed to list deployments \nreason: #{inspect(error)}")
    end
  end

  def update(deployment, key, value, opts, auth \\ nil) do
    auth = auth || Shell.request_auth()
    product = opts[:product] || default_product()
    case API.Deployment.update(product, deployment, Map.put(%{}, key, value), auth) do
      {:ok, %{"data" => deployment}} ->
        Shell.info("")
        Shell.info("Deployment Updated:")

        render_deployment(deployment)
        |> String.trim_trailing()
        |> Shell.info()

        Shell.info("")

      error ->
        Shell.info("Failed to update deployment \nreason: #{inspect(error)}")
    end
  end

  defp render_deployment(params) do
    """
      name:      #{params["name"]}
      is_active: #{params["is_active"]}
      firmware:  #{params["firmware_uuid"]}
      #{render_conditions(params["conditions"])}
    """
  end

  defp render_conditions(conditions) do
    """
    conditions:
    """ <>
      if Map.get(conditions, "version") != "" do
        """
            version: #{conditions["version"]}
        """
      else
        ""
      end <>
      """
          #{render_tags(conditions["tags"])}
      """
  end

  defp render_tags(tags) do
    """
    tags: [#{Enum.join(tags, ", ")}]
    """
  end
end

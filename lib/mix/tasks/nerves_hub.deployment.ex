defmodule Mix.Tasks.NervesHub.Deployment do
  use Mix.Task

  @shortdoc "Manages NervesHub deployments"

  @moduledoc """
  Manage NervesHub deployments

  ## list

    mix nerves_hub.deployment list

  ### Command-line options

    * `--product` - (Optional) Only show deployments for one product.
      This defaults to the Mix Project config `:app` name.

  ## create

  Create a new deployment

    mix nerves_hub.deployment create

  ### Command-line options

    * `--name` - (Optional) The deployment name
    * `--firmware` - (Optional) The firmware UUID
    * `--version` - (Optional) Can be blank. The version requirement the device's
      version must meet to qualify for the deployment
    * `--tag` - (Optional) Multiple tags can be set by passing this key multiple
      times

  ## update

  Update values on a deployment.

  ### Examples

  Update active firmware version

    mix nerves_hub.deployment update dev firmware fd53d87c-99ca-5770-5540-edb5058ced5b

  Activate / Deactivate a deployment

    mix nerves_hub.deployment update dev is_active true

  General usage:

    mix nerves_hub.firmware update [deployment_name] [key] [value]

  """

  import Mix.NervesHubCLI.Utils

  alias Mix.NervesHubCLI.Shell

  @switches [
    org: :string,
    product: :string,
    name: :string,
    version: :string,
    firmware: :string,
    tag: :keep
  ]

  def run(args) do
    Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    show_api_endpoint()
    org = org(opts)
    product = product(opts)

    case args do
      ["list"] ->
        list(org, product)

      ["create"] ->
        create(org, product, opts)

      ["update", deployment, key, value] ->
        update(deployment, key, value, org, product)

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.raise("""
    Invalid arguments to `mix nerves_hub.deployment`.

    Usage:
      mix nerves_hub.deployment list
      mix nerves_hub.deployment create
      mix nerves_hub.deployment update DEPLOYMENT_NAME KEY VALUE

    Run `mix help nerves_hub.deployment` for more information.
    """)
  end

  def list(org, product) do
    auth = Shell.request_auth()

    case NervesHubCore.Deployment.list(org, product, auth) do
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
        end)

        Shell.info("------------")
        Shell.info("")

      error ->
        Shell.render_error(error)
    end
  end

  def create(org, product, opts) do
    name = opts[:name] || Shell.prompt("Deployment name:")
    firmware = opts[:firmware] || Shell.prompt("firmware uuid:")
    vsn = opts[:version] || Shell.prompt("version condition:")

    tags = Keyword.get_values(opts, :tag)

    tags =
      if tags == [] do
        Shell.prompt("tags:")
        |> String.split()
      else
        tags
      end

    auth = Shell.request_auth()

    case NervesHubCore.Deployment.create(org, product, name, firmware, vsn, tags, auth) do
      {:ok, %{"data" => %{} = _deployment}} ->
        Shell.info("Deployment #{name} created")

      error ->
        Shell.render_error(error)
    end
  end

  def update(deployment, key, value, org, product, auth \\ nil) do
    auth = auth || Shell.request_auth()

    case NervesHubCore.Deployment.update(org, product, deployment, Map.put(%{}, key, value), auth) do
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

defmodule NervesHubCLI.Directives.Deployment do
  # @shortdoc "Manages NervesHub deployments"

  @moduledoc """
  Manage NervesHub deployments

  ## list

      nh deployment list

  ### Command-line options

    * `--product` - (Optional) Only show deployments for one product.
      This defaults to the Mix Project config `:app` name.

  ## create

  Create a new deployment

      nh deployment create

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

      nh deployment update dev firmware fd53d87c-99ca-5770-5540-edb5058ced5b

  Activate / Deactivate a deployment

      nh deployment update dev is_active true

  General usage:

      nh firmware update [deployment_name] [key] [value]

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
    _ = Application.ensure_all_started(:nerves_hub_cli)

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
    Shell.info("""


    Usage:
      nh deployment list
      nh deployment create
      nh deployment update DEPLOYMENT_NAME KEY VALUE


    """)
  end

  def list(org, product) do
    auth = Shell.request_auth()

    case NervesHubUserAPI.Deployment.list(org, product, auth) do
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
    firmware = opts[:firmware] || Shell.prompt("Firmware uuid:")
    vsn = opts[:version] || Shell.prompt("Version condition:")

    # Tags may be specified using multiple `--tag` options or as `--tag "a, b, c"`
    tags = Keyword.get_values(opts, :tag) |> Enum.flat_map(&split_tag_string/1)

    tags =
      if tags == [] do
        Shell.prompt("One or more comma-separated device tags:")
        |> split_tag_string()
      else
        tags
      end

    auth = Shell.request_auth()

    case NervesHubUserAPI.Deployment.create(org, product, name, firmware, vsn, tags, auth) do
      {:ok, %{"data" => %{} = _deployment}} ->
        Shell.info("""

        Deployment #{name} created.

        This deployment is not activated by default. To activate it, run:

        nh deployment update #{name} is_active true
        """)

      error ->
        Shell.render_error(error)
    end
  end

  def update(deployment, key, value, org, product, auth \\ nil) do
    auth = auth || Shell.request_auth()

    case NervesHubUserAPI.Deployment.update(
           org,
           product,
           deployment,
           Map.put(%{}, key, value),
           auth
         ) do
      {:ok, %{"data" => deployment}} ->
        Shell.info("")
        Shell.info("Deployment updated:")

        render_deployment(deployment)
        |> String.trim_trailing()
        |> Shell.info()

        Shell.info("")

      error ->
        Shell.info("Failed to update deployment.\nReason: #{inspect(error)}")
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
    device tags: [#{Enum.join(tags, ", ")}]
    """
  end
end

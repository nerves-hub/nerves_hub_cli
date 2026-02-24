defmodule NervesHubCLI.API.Script do
  @moduledoc """
  Manage NervesHub support scripts

  Scripts are defined at the product level and can be sent to individual devices.
  """

  alias NervesHubCLI.API
  alias NervesHubCLI.API.Auth
  alias NervesHubCLI.API.Device
  alias NervesHubCLI.API.Product

  @path "scripts"

  @doc """
  List scripts available for a product.

  Verb: GET
  Path: /orgs/:org_name/products/:product_name/scripts
  """
  @spec list(String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def list(org_name, product_name, %Auth{} = auth) do
    API.request(:get, path(org_name, product_name), %{}, auth)
  end

  @doc """
  Send a script to a device for execution.

  Verb: POST
  Path: /orgs/:org_name/products/:product_name/devices/:device_identifier/scripts/:name_or_id

  Options:
    * `:timeout` - How long to wait for device response in milliseconds (default: 30000)
  """
  @spec send(String.t(), String.t(), String.t(), String.t(), keyword(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def send(org_name, product_name, device_identifier, name_or_id, opts \\ [], %Auth{} = auth) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    script_path = Path.join(device_path(org_name, product_name, device_identifier), name_or_id)
    API.request(:post, "#{script_path}?timeout=#{timeout}", %{}, auth)
  end

  @doc false
  @spec path(String.t(), String.t()) :: String.t()
  def path(org_name, product_name) do
    Path.join(Product.path(org_name, product_name), @path)
  end

  @doc false
  @spec device_path(String.t(), String.t(), String.t()) :: String.t()
  def device_path(org_name, product_name, device_identifier) do
    Path.join(Device.path(org_name, product_name, device_identifier), @path)
  end
end

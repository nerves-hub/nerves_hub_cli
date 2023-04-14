defmodule NervesHubCLI.API.Deployment do
  @moduledoc """
  Manage NervesHub deployments

  Path: /orgs/:org_name/products/:product_name/deployments
  """
  alias NervesHubCLI.API
  alias NervesHubCLI.API.Auth
  alias NervesHubCLI.API.Product

  @path "deployments"

  @doc """
  List all deployments for a product.

  Verb: GET
  Path: /orgs/:org_name/products/:product_name/deployments
  """
  @spec list(String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def list(org_name, product_name, %Auth{} = auth) do
    API.request(:get, path(org_name, product_name), "", auth)
  end

  @doc """
  Create a new deployment.

  Verb: POST
  Path: /orgs/:org_name/products/:product_name/deployments
  """
  @spec create(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          [String.t()],
          NervesHubCLI.API.Auth.t()
        ) :: {:error, any()} | {:ok, any()}
  def create(org_name, product_name, name, firmware_uuid, version, tags, %Auth{} = auth) do
    params = %{
      name: name,
      firmware: firmware_uuid,
      conditions: %{version: version, tags: tags},
      is_active: false
    }

    API.request(:post, path(org_name, product_name), params, auth)
  end

  @doc """
  Update an existing deployment.

  Verb: PUT
  Path: /orgs/:org_name/products/:product_name/deployments/:depolyment_name
  """
  @spec update(String.t(), String.t(), String.t(), map(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def update(org_name, product_name, deployment_name, params, %Auth{} = auth) do
    params = %{deployment: params}
    API.request(:put, path(org_name, product_name, deployment_name), params, auth)
  end

  @doc false
  @spec path(String.t(), String.t()) :: String.t()
  def path(org_name, product_name) do
    Path.join(Product.path(org_name, product_name), @path)
  end

  @doc false
  @spec path(String.t(), String.t(), String.t()) :: String.t()
  def path(org_name, product_name, deployment_name) do
    Path.join(path(org_name, product_name), deployment_name)
  end
end

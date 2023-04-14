defmodule NervesHubCLI.API.Product do
  @moduledoc """
  Manage products on NervesHub

  Path: /orgs/:org_name/products
  """

  alias NervesHubCLI.API
  alias NervesHubCLI.API.Auth
  alias NervesHubCLI.API.Org

  @path "products"

  @doc """
  List all products for an org.

  Verb: GET
  Path: /orgs/:org_name/products
  """
  @spec list(String.t(), NervesHubCLI.API.Auth.t()) :: {:error, any()} | {:ok, any()}
  def list(org_name, %Auth{} = auth) do
    API.request(:get, path(org_name), "", auth)
  end

  @doc """
  Create a new product.

  Verb: POST
  Path: /orgs/:org_name/products
  """
  @spec create(String.t(), any(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def create(org_name, product_name, %Auth{} = auth) do
    params = %{name: product_name}
    API.request(:post, path(org_name), params, auth)
  end

  @doc """
  Delete an existing product.

  Verb: DELETE
  Path: /orgs/:org_name/products/:product_name
  """
  @spec delete(String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def delete(org_name, product_name, %Auth{} = auth) do
    API.request(:delete, path(org_name, product_name), "", auth)
  end

  @doc """
  Update parameters of an existing product.

  Verb: PUT
  Path: /orgs/:org_name/products/:product_name
  """
  @spec update(String.t(), String.t(), map(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def update(org_name, product_name, params, %Auth{} = auth) do
    params = %{product: params}
    API.request(:put, path(org_name, product_name), params, auth)
  end

  @doc false
  @spec path(String.t()) :: String.t()
  def path(org_name) do
    Path.join(Org.path(org_name), @path)
  end

  @doc false
  @spec path(String.t(), String.t()) :: String.t()
  def path(org_name, product_name) when is_atom(product_name),
    do: path(org_name, to_string(product_name))

  def path(org_name, product_name) do
    Path.join(path(org_name), product_name)
  end
end

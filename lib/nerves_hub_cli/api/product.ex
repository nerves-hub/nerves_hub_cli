defmodule NervesHubCLI.API.Product do
  alias NervesHubCLI.API
  alias NervesHubCLI.API.Org

  @path "products"

  def path(org) do
    Path.join([Org.path(org), @path])
  end

  def path(org, product) when is_atom(product), do: path(org, to_string(product))

  def path(org, product) do
    Path.join([path(org), product])
  end

  def list(org, auth) do
    API.request(:get, path(org), "", auth)
  end

  def create(org, product, auth) do
    params = %{name: product}
    API.request(:post, path(org), params, auth)
  end

  def delete(org, product, auth) do
    API.request(:delete, path(org, product), "", auth)
  end

  def update(org, product, params, auth) do
    params = %{product: params}
    API.request(:put, path(org, product), params, auth)
  end
end

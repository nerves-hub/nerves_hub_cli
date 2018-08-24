defmodule NervesHubCLI.API.Deployment do
  alias NervesHubCLI.API
  alias NervesHubCLI.API.Product

  @path "deployments"

  def path(org, product) do
    Path.join([Product.path(org, product), @path])
  end

  def path(org, product, deployment) do
    Path.join([path(org, product), deployment])
  end

  def list(org, product, auth) do
    API.request(:get, path(org, product), "", auth)
  end

  def create(org, product, name, firmware, version, tags, auth) do
    params = %{
      name: name,
      firmware: firmware,
      conditions: %{version: version, tags: tags},
      is_active: false
    }

    API.request(:post, path(org, product), params, auth)
  end

  def update(org, product, deployment, params, auth) do
    params = %{deployment: params}
    API.request(:put, path(org, product, deployment), params, auth)
  end
end

defmodule NervesHubCLI.API.Key do
  alias NervesHubCLI.API
  alias NervesHubCLI.API.Org

  @path "keys"

  def path(org) do
    Path.join([Org.path(org), @path])
  end

  def path(org, key) do
    Path.join([path(org), key])
  end

  def list(org, auth) do
    API.request(:get, path(org), "", auth)
  end

  def create(org, name, key, auth) do
    params = %{name: name, key: key}
    API.request(:post, path(org), params, auth)
  end

  def delete(org, name, auth) do
    API.request(:delete, path(org, name), "", auth)
  end
end

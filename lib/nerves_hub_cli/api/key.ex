defmodule NervesHubCLI.API.Key do
  alias NervesHubCLI.API

  def list(auth) do
    API.request(:get, "keys", "", auth)
  end

  def create(name, key, auth) do
    params = %{name: name, key: key}
    API.request(:post, "keys", params, auth)
  end

  def delete(name, auth) do
    API.request(:delete, "keys/#{name}", "", auth)
  end
end

defmodule NervesHubCLI.API.Firmware do
  alias NervesHubCLI.API
  alias NervesHubCLI.API.Product

  @path "firmwares"

  def path(org, product) do
    Path.join([Product.path(org, product), @path])
  end

  def list(org, product, auth) do
    API.request(:get, path(org, product), "", auth)
  end

  def create(org, product, tar, auth) do
    API.file_request(:post, path(org, product), tar, auth)
  end

  def delete(org, product, uuid, auth) do
    path = Path.join(path(org, product), uuid)
    API.request(:delete, path, "", auth)
  end
end

defmodule NervesHubCLI.API.Firmware do
  alias NervesHubCLI.API

  def list(product_name, auth) do
    API.request(:get, "firmwares", %{product_name: product_name}, auth)
  end

  def create(tar, auth) do
    API.file_request(:post, "firmwares", tar, auth)
  end

  def delete(uuid, auth) do
    API.request(:delete, "firmwares/#{uuid}", "", auth)
  end
end

defmodule NervesHubCLI.API.Device do
  alias NervesHubCLI.API

  def create(identifier, description, tags, auth) do
    params = %{identifier: identifier, description: description, tags: tags}
    API.request(:post, "devices", params, auth)
  end

  def cert_list(identifier, auth) do
    API.request(:get, "devices/#{identifier}/certificates", "", auth)
  end

  def cert_create(identifier, auth) do
    params = %{}
    API.request(:post, "devices/#{identifier}/certificates", params, auth)
  end

  def cert_sign(identifier, csr, auth) do
    params = %{identifier: identifier, csr: csr}
    API.request(:post, "devices/#{identifier}/certificates/sign", params, auth)
  end
end

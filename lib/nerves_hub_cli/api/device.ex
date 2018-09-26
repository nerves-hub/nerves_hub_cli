defmodule NervesHubCLI.API.Device do
  alias NervesHubCLI.API
  alias NervesHubCLI.API.Org

  @path "devices"

  def path(org) do
    Path.join([Org.path(org), @path])
  end

  def path(org, device) do
    Path.join([path(org), device])
  end

  def cert_path(org, device) do
    Path.join(path(org, device), "certificates")
  end

  def create(org, identifier, description, tags, auth) do
    params = %{identifier: identifier, description: description, tags: tags}
    API.request(:post, path(org), params, auth)
  end

  def update(org, identifier, data, auth) do
    params = Map.merge(data, %{identifier: identifier})
    API.request(:put, path(org, identifier), params, auth)
  end

  def cert_list(org, identifier, auth) do
    API.request(:get, cert_path(org, identifier), "", auth)
  end

  def cert_create(org, identifier, auth) do
    params = %{}
    API.request(:post, cert_path(org, identifier), params, auth)
  end

  def cert_sign(org, identifier, csr, auth) do
    params = %{identifier: identifier, csr: csr}
    path = Path.join(cert_path(org, identifier), "sign")
    API.request(:post, path, params, auth)
  end
end

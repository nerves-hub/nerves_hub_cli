defmodule NervesHubCLI.API.CACertificate do
  alias NervesHubCLI.API
  alias NervesHubCLI.API.Org

  @path "ca_certificates"

  def path(org) do
    Path.join([Org.path(org), @path])
  end

  def path(org, serial) do
    Path.join([path(org), serial])
  end

  def list(org, auth) do
    API.request(:get, path(org), "", auth)
  end

  def create(org, cert_pem, auth) do
    params = %{cert: Base.encode64(cert_pem)}
    API.request(:post, path(org), params, auth)
  end

  def delete(org, serial, auth) do
    API.request(:delete, path(org, serial), "", auth)
  end
end

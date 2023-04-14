defmodule NervesHubCLI.API.Device do
  @moduledoc """
  Manage NervesHub devices

  Path: /orgs/:org_name/products/:product_name/devices
  """

  alias NervesHubCLI.API
  alias NervesHubCLI.API.Auth
  alias NervesHubCLI.API.DeviceCertificate
  alias NervesHubCLI.API.Product

  @path "devices"

  @doc """
  List all devices.

  Verb: GET
  Path: /orgs/:org_name/products/:product_name/devices
  """
  @spec list(String.t(), String.t(), NervesHubCLI.API.Auth.t()) :: {:error, any()} | {:ok, any()}
  def list(org_name, product_name, %Auth{} = auth) do
    API.request(:get, path(org_name, product_name), "", auth)
  end

  @doc """
  Create a new device.

  Verb: POST
  Path: /orgs/:org_name/products/:product_name/devices
  """
  @spec create(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          [String.t()],
          NervesHubCLI.API.Auth.t()
        ) ::
          {:error, any()} | {:ok, any()}
  def create(org_name, product_name, identifier, description, tags, %Auth{} = auth) do
    params = %{identifier: identifier, description: description, tags: tags}
    API.request(:post, path(org_name, product_name), params, auth)
  end

  @doc """
  Update an existing device.

  Verb: PUT
  Path: /orgs/:org_name/products/:product_name/devices/:device_identifier
  """
  @spec update(String.t(), String.t(), String.t(), map(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def update(org_name, product_name, device_identifier, params, %Auth{} = auth) do
    params = Map.merge(params, %{identifier: device_identifier})
    API.request(:put, path(org_name, product_name, device_identifier), params, auth)
  end

  @doc """
  Delete an existing device.

  Verb: DELETE
  Path: /orgs/:org_name/products/:product_name/devices/:device_identifer
  """
  @spec delete(String.t(), String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def delete(org_name, product_name, device_identifier, %Auth{} = auth) do
    API.request(:delete, path(org_name, product_name, device_identifier), "", auth)
  end

  @doc """
  Check authentication status for device certificate.

  Verb: POST
  Path: /orgs/:org_name/products/:product_name/devices/auth
  """
  @spec auth(String.t(), String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def auth(org_name, product_name, cert_pem, %Auth{} = auth) do
    params = %{certificate: Base.encode64(cert_pem)}
    path = Path.join(path(org_name, product_name), "auth")
    API.request(:post, path, params, auth)
  end

  @deprecated "use NervesHubCLI.API.DeviceCertificate.list/4 instead"
  def cert_list(org_name, product_name, device_identifier, %Auth{} = auth) do
    DeviceCertificate.list(org_name, product_name, device_identifier, auth)
  end

  @deprecated "use NervesHubCLI.API.DeviceCertificate.sign/5 instead"
  def cert_sign(org_name, product_name, device_identifier, csr, %Auth{} = auth) do
    DeviceCertificate.sign(org_name, product_name, device_identifier, csr, auth)
  end

  @doc false
  @spec path(String.t(), String.t()) :: String.t()
  def path(org_name, product_name) do
    Path.join(Product.path(org_name, product_name), @path)
  end

  @doc false
  @spec path(String.t(), String.t(), String.t()) :: String.t()
  def path(org_name, product_name, device_identifier) do
    Path.join(path(org_name, product_name), device_identifier)
  end
end

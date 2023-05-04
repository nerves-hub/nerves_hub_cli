defmodule NervesHubCLI.API.DeviceCertificate do
  @moduledoc """
  Manage NervesHub device certificates

  Path: /orgs/:org_name/products/:product_name/devices/:device_identifier/certificates
  """

  alias NervesHubCLI.API
  alias NervesHubCLI.API.Auth
  alias NervesHubCLI.API.Device

  @path "certificates"

  @doc """
  List certificates for a device.

  Verb: GET
  Path: /orgs/:org_name/products/:product_name/devices/:device_identifier/certificates
  """
  @spec list(String.t(), String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def list(org_name, product_name, device_identifier, %Auth{} = auth) do
    API.request(:get, path(org_name, product_name, device_identifier), "", auth)
  end

  @doc """
  Upload a trusted certificate for a device.

  Verb: POST
  Path: /orgs/:org_name/products/:product_name/devices/:device_identifier/certificates
  """
  @spec create(String.t(), String.t(), String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def create(org_name, product_name, device_identifier, pem, %Auth{} = auth) do
    params = %{identifier: device_identifier, cert: Base.encode64(pem)}
    path = path(org_name, product_name, device_identifier)
    API.request(:post, path, params, auth)
  end

  @doc """
  Removes the Device certificate with the specified serial number from NervesHub.

  Verb: DELETE
  Path: /orgs/:org_name/products/:product_name/devices/:device_identifier/certificates/:serial
  """
  @spec delete(String.t(), String.t(), String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def delete(org_name, product_name, device_identifier, serial, %Auth{} = auth) do
    path = path(org_name, product_name, device_identifier, serial)
    API.request(:delete, path, "", auth)
  end

  @doc false
  @spec path(String.t(), String.t(), String.t()) :: String.t()
  def path(org_name, product_name, device_identifier) do
    Path.join(Device.path(org_name, product_name, device_identifier), @path)
  end

  @spec path(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def path(org_name, product_name, device_identifier, serial) do
    Path.join(path(org_name, product_name, device_identifier), serial)
  end
end

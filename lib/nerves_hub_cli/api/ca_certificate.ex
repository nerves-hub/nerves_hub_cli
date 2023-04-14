defmodule NervesHubCLI.API.CACertificate do
  @moduledoc """
  CA certificates

  Path: /orgs/:org_name/ca_certificates
  """

  alias NervesHubCLI.API
  alias NervesHubCLI.API.Auth
  alias NervesHubCLI.API.Org

  @path "ca_certificates"

  @doc """
  List all ca certificates for an organization

  Verb: GET
  Path: /orgs/:org_name/ca_certificates
  """
  @spec list(String.t(), NervesHubCLI.API.Auth.t()) :: {:error, any()} | {:ok, any()}
  def list(org_name, %Auth{} = auth) do
    API.request(:get, path(org_name), "", auth)
  end

  @doc """
  Adds a new CA certificate to NervesHub. The certificate passed should be
  pem encoded binary and not a path to the cert file.

  Verb: POST
  Path: /orgs/:org_name/ca_certificates
  """
  @spec create(String.t(), String.t(), NervesHubCLI.API.Auth.t(), String.t() | nil) ::
          {:error, any()} | {:ok, any()}
  def create(org_name, cert_pem, %Auth{} = auth, description \\ nil) do
    params = %{
      cert: Base.encode64(cert_pem),
      description: description
    }

    API.request(:post, path(org_name), params, auth)
  end

  @doc """
  Removes the CA certificate with the specified serial number from NervesHub.

  Verb: DELETE
  Path: /orgs/:org_name/ca_certificates/:serial
  """
  @spec delete(String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def delete(org_name, serial, %Auth{} = auth) do
    API.request(:delete, path(org_name, serial), "", auth)
  end

  @doc false
  @spec path(String.t()) :: String.t()
  def path(org_name) do
    Path.join(Org.path(org_name), @path)
  end

  @doc false
  @spec path(String.t(), String.t()) :: String.t()
  def path(org_name, serial) do
    Path.join(path(org_name), serial)
  end
end

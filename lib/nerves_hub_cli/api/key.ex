defmodule NervesHubCLI.API.Key do
  @moduledoc """
  Manages firmware signing keys

  Path: /orgs/:org_name/keys
  """

  alias NervesHubCLI.API
  alias NervesHubCLI.API.Auth
  alias NervesHubCLI.API.Org

  @path "keys"

  @doc """
  List all keys for an org.

  Verb: GET
  Path: /orgs/:org_name/keys
  """
  @spec list(String.t(), NervesHubCLI.API.Auth.t()) :: {:error, any()} | {:ok, any()}
  def list(org_name, %Auth{} = auth) do
    API.request(:get, path(org_name), "", auth)
  end

  @doc """
  Add a public firmware signing key.

  Verb: POST
  Path: /orgs/:org_name/keys
  """
  @spec create(String.t(), String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def create(org_name, key_name, key, %Auth{} = auth) do
    params = %{name: key_name, key: key}
    API.request(:post, path(org_name), params, auth)
  end

  @doc """
  Delete a firmware signing key.

  Verb: DELETE
  Path: /orgs/:org_name/keys/:key_name
  """
  @spec delete(String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def delete(org_name, key_name, %Auth{} = auth) do
    API.request(:delete, path(org_name, key_name), "", auth)
  end

  @doc false
  @spec path(String.t()) :: String.t()
  def path(org_name) do
    Path.join(Org.path(org_name), @path)
  end

  @doc false
  @spec path(String.t(), String.t()) :: String.t()
  def path(org_name, key_name) do
    Path.join(path(org_name), key_name)
  end
end

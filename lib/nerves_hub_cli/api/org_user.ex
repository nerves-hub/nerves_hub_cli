defmodule NervesHubCLI.API.OrgUser do
  @moduledoc """
  Manage OrgUsers on NervesHub

  Path: /orgs/:org_name/users
  """

  alias NervesHubCLI.API
  alias NervesHubCLI.API.Auth
  alias NervesHubCLI.API.Org

  @type role :: :admin | :delete | :write | :read

  @path "users"
  @roles [:admin, :delete, :write, :read]

  @doc """
  List all users for an org.

  Verb: GET
  Path: /orgs/:org_name/users
  """
  @spec list(String.t(), NervesHubCLI.API.Auth.t()) :: {:error, any()} | {:ok, any()}
  def list(org_name, %Auth{} = auth) do
    API.request(:get, path(org_name), "", auth)
  end

  @doc """
  Add a user to the org with a role.

  Verb: POST
  Path: /orgs/:org_name/users
  """
  @spec add(String.t(), String.t(), NervesHubCLI.API.role(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def add(org_name, username, role, %Auth{} = auth) when role in @roles do
    params = %{username: username, role: role}
    API.request(:post, path(org_name), params, auth)
  end

  def add(_org_name, _username, _role, _auth) do
    {:error, :invalid_role}
  end

  @doc """
  Update an existing org user's role.

  Verb: PUT
  Path: /orgs/:org_name/users/:username
  """
  @spec update(String.t(), String.t(), NervesHubCLI.API.role(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def update(org_name, username, role, %Auth{} = auth) do
    params = %{role: role}
    API.request(:put, path(org_name, username), params, auth)
  end

  @doc """
  Remove a user from the org.

  Verb: DELETE
  Path: /orgs/:org_name/users/:username
  """
  @spec remove(String.t(), String.t(), NervesHubCLI.API.Auth.t()) ::
          {:error, any()} | {:ok, any()}
  def remove(org_name, username, %Auth{} = auth) do
    API.request(:delete, path(org_name, username), "", auth)
  end

  @spec path(String.t()) :: String.t()
  def path(org) when is_atom(org), do: to_string(org) |> path()

  def path(org) when is_binary(org) do
    Path.join(Org.path(org), @path)
  end

  @doc false
  @spec path(String.t(), String.t()) :: String.t()
  def path(org_name, username) do
    Path.join(path(org_name), username)
  end
end

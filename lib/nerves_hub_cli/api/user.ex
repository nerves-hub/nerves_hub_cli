defmodule NervesHubCLI.API.User do
  @moduledoc """
  Manage NervesHub users

  Path: /users
  """

  alias NervesHubCLI.API
  alias NervesHubCLI.API.Auth

  # Certificate protected
  @doc """
  Returns information about the user.

  Verb: GET
  Path: /users/me
  """
  @spec me(NervesHubCLI.API.Auth.t()) :: {:error, any()} | {:ok, any()}
  def me(%Auth{} = auth) do
    API.request(:get, "users/me", "", auth)
  end

  # Username / Password protected endpoints
  @doc """
  Register a new user.

  Verb: POST
  Path: /users/register
  """
  @spec register(String.t(), String.t(), String.t()) :: {:error, any()} | {:ok, any()}
  def register(username, email, password) do
    params = %{username: username, email: email, password: password}
    API.request(:post, "users/register", params)
  end

  @doc """
  Validate authentication of an existing user.

  Verb: POST
  Path: /users/auth
  """
  @spec auth(String.t(), String.t()) :: {:error, any()} | {:ok, any()}
  def auth(email, password) do
    params = %{email: email, password: password}
    API.request(:post, "users/auth", params)
  end

  @doc """
  Validate authentication of a user and create an access token for future use

  Verb: POST
  Path: /users/login

  A `note` is required for the generated token. Defaults to the client
  hostname if not supplied.
  """
  @spec login(String.t(), String.t()) :: {:error, any()} | {:ok, any()}
  def login(email, password, note \\ nil) do
    note = note || get_hostname()
    params = %{email: email, password: password, note: note}
    API.request(:post, "users/login", params)
  end

  defp get_hostname() do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end

  @doc """
  Sign a user certificate for an existing user.

  Verb: POST
  Path: /users/sign
  """
  @spec sign(String.t(), String.t(), String.t(), String.t()) :: {:error, any()} | {:ok, any()}
  def sign(email, password, csr, description) do
    params = %{email: email, password: password, csr: csr, description: description}
    API.request(:post, "users/sign", params)
  end
end

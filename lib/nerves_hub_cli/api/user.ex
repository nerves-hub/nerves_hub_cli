defmodule NervesHubCLI.API.User do
  alias NervesHubCLI.API

  # Certificate protected

  def me(auth) do
    API.request(:get, "users/me", "", auth)
  end

  # Username / Password protected endpoints

  def register(username, email, password) do
    params = %{username: username, email: email, password: password}
    API.request(:post, "users/register", params)
  end

  def auth(email, password) do
    params = %{email: email, password: password}
    API.request(:post, "users/auth", params)
  end

  def sign(email, password, csr, description) do
    params = %{email: email, password: password, csr: csr, description: description}
    API.request(:post, "users/sign", params)
  end
end

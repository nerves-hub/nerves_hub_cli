defmodule NervesHubCLI.API.Product do
  # alias NervesHubCLI.API
  alias NervesHubCLI.API.Org

  @path "products"

  def path(org) do
    Path.join([Org.path(org), @path])
  end

  def path(org, product) when is_atom(product), do: path(org, to_string(product))

  def path(org, product) do
    Path.join([path(org), product])
  end
end

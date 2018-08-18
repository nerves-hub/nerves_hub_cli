defmodule NervesHubCLI.API.Org do
  @path "orgs"

  def path(org) when is_atom(org), do: to_string(org) |> path()

  def path(org) when is_binary(org) do
    Path.join([@path, org])
  end
end

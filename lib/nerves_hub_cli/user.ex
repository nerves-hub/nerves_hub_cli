defmodule NervesHubCLI.User do
  @spec deauth() :: :ok
  def deauth() do
    _ = NervesHubCLI.Config.delete(:token)
    :ok
  end
end

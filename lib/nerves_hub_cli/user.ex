defmodule NervesHubCLI.User do
  @spec init :: :ok
  def init() do
    File.mkdir_p!(data_dir())

    :ok
  end

  @spec deauth() :: :ok
  def deauth() do
    _ = NervesHubCLI.Config.delete(:token)
    :ok
  end

  defp data_dir() do
    Path.join(NervesHubCLI.home_dir(), "user_data")
  end
end

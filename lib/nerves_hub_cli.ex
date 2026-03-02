defmodule NervesHubCLI do
  @moduledoc false

  @typedoc """
  Firmware update public keys can be referred to by their contents.
  """
  @type fwup_public_key_ref :: String.t()

  @spec default_description() :: String.t()
  def default_description() do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end

  @spec data_dir() :: String.t()
  def data_dir() do
    override_dir =
      System.get_env("NERVES_CLOUD_DATA_DIR") || System.get_env("NERVES_HUB_DATA_DIR")

    if override_dir == nil or override_dir == "" do
      Path.expand("~/.nerves-hub")
    else
      override_dir
    end
  end
end

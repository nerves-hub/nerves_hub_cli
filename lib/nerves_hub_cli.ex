defmodule NervesHubCli do
  
  def home_dir do
    System.get_env("NERVES_HUB_HOME") || Path.expand("~/.nerves_hub")
  end
  
end

defmodule NervesHubCliTest do
  use ExUnit.Case
  doctest NervesHubCli

  test "greets the world" do
    assert NervesHubCli.hello() == :world
  end
end

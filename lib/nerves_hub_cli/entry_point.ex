defmodule NervesHubCLI.EntryPoint do
  @moduledoc false

  def start(_, _) do
    Burrito.Util.Args.argv()
    |> NervesHubCLI.CLI.main()

    System.halt(0)
  end
end

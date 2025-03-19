defmodule NervesHubCLI.EntryPoint do
  @moduledoc false

  def start(_, _) do
    Burrito.Util.Args.argv()
    |> NervesHubCLI.CLI.main()

    System.halt(0)
  rescue
    error ->
      IO.puts("An error occurred: #{inspect(error)}")
      System.halt(1)
  catch
    error ->
      IO.puts("An error was caught: #{inspect(error)}")
      System.halt(1)
  end
end

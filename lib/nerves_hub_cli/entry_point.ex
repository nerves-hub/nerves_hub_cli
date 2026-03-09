defmodule NervesHubCLI.EntryPoint do
  @moduledoc false

  def start(_, _) do
    if System.get_env("__BURRITO") do
      if System.get_env("NERVES_HUB_TUI") == "1" do
        NervesHubCLI.TUI.run()
      else
        Burrito.Util.Args.argv()
        |> NervesHubCLI.CLI.main()
      end

      System.halt(0)
    else
      {:ok, self()}
    end
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

defmodule NervesHubCLI.Cmd do
  def fwup(args, path) do
    path = path || File.cwd!()

    case System.cmd("fwup", args, stderr_to_stdout: true, cd: path) do
      {_output, 0} -> :ok
      {error, _} -> {:error, error}
    end
  end
end

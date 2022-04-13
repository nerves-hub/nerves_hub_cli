defmodule NervesHubCLI.Config do
  @config "nerves-hub.config"

  def delete(key) do
    read()
    |> Map.delete(key)
    |> write()
  end

  def put(key, value) do
    read()
    |> Map.put(key, value)
    |> write()
  end

  def get(key) do
    read()
    |> Map.get(key)
  end

  defp read do
    with {:ok, binary} <- File.read(file()),
         {:ok, term} <- PBCS.Utils.safe_binary_to_term(binary) do
      term
    else
      _ -> %{}
    end
  end

  defp write(config) do
    File.write(file(), :erlang.term_to_binary(config))
  end

  defp file do
    Path.join(data_dir(), @config)
  end

  def data_dir() do
    NervesHubCLI.home_dir()
  end
end

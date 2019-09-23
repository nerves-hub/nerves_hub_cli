defmodule Mix.NervesHubCLI.Bulk do
  alias Mix.NervesHubCLI.Shell
  import Mix.NervesHubCLI.Utils

  def create_devices(data, org, product, auth) do
    data
    |> Enum.filter(fn
      [_identifier, _tags, _description] ->
        true

      _ ->
        # maybe raise/exit here? 
        false
    end)
    |> Enum.map(fn [identifier, tags, description] ->
      tags = split_tag_string(tags)

      Task.async(fn ->
        result = NervesHubUserAPI.Device.create(org, product, identifier, description, tags, auth)
        {result, [identifier, description, tags]}
      end)
    end)
    |> Task.yield_many(:infinity)
    |> Enum.filter(fn
      {task, nil} ->
        _ = Task.shutdown(task, :brutal_kill)
        false

      {_task, {:ok, {{:ok, %{} = _device}, _}}} ->
        true

      {_task, {:ok, {error, [identifier, description, tags]}}} ->
        Shell.error(
          "Error creating #{identifier} with tags: #{inspect(tags)} and description: #{
            description
          }"
        )

        Shell.render_error(error, false)
        false
    end)
    |> Enum.map(fn {_task, {:ok, {{:ok, %{} = device}, _}}} ->
      device
    end)
  end
end

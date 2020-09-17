defmodule NervesHubCLI.Bulk do
  alias NervesHubCLI.Shell
  import NervesHubCLI.Utils

  @acc %{data: [], error: [], malformed: [], success: [], tasks: []}

  def create_devices(data, org, product, auth) do
    %{@acc | data: data}
    |> filter_malformed()
    |> do_create_devices(org, product, auth)
    |> accumulate_results()
  end

  def display_results(%{error: error, malformed: malformed, success: success}, csv_path) do
    _ = Enum.each(error, &display_error/1)

    _ = Enum.each(malformed, &display_malformed(&1, csv_path))

    Shell.info("""
    Results:
      #{IO.ANSI.yellow()}malformed: #{length(malformed)}
      #{IO.ANSI.red()}errors: #{length(error)}
      #{IO.ANSI.green()}successful: #{length(success)}
    #{IO.ANSI.default_color()}
    """)
  end

  defp accumulate_results(acc) do
    Enum.reduce(acc.tasks, acc, fn
      {task, nil}, acc ->
        _ = Task.shutdown(task, :brutal_kill)
        acc

      {_task, {:ok, {{:ok, %{} = device}, _}}}, acc ->
        %{acc | success: [device | acc.success]}

      {_task, {:ok, {_error, [_i, _d_, _t]} = err}}, acc ->
        %{acc | error: [err | acc.error]}
    end)
  end

  defp display_error({error, [identifier, description, tags]}) do
    Shell.error("""
    Error creating #{identifier} with tags: #{inspect(tags)} and description: #{description} ¬
      #{inspect(error)}
    """)
  end

  defp display_malformed({line, line_num}, csv_path) do
    Shell.info("""
    #{IO.ANSI.yellow()} Malformed CSV line - #{inspect(line)}
      (CSV) #{csv_path}:#{line_num}
    #{IO.ANSI.default_color()}
    """)
  end

  defp do_create_devices(acc, org, product, auth) do
    tasks =
      Enum.map(acc.data, fn [identifier, tags, description] ->
        tags = split_tag_string(tags)

        Task.async(fn ->
          result =
            NervesHubUserAPI.Device.create(org, product, identifier, description, tags, auth)

          {result, [identifier, description, tags]}
        end)
      end)

    %{acc | tasks: Task.yield_many(tasks, :infinity)}
  end

  defp filter_malformed(acc) do
    Enum.with_index(acc.data)
    |> Enum.reduce(%{acc | data: []}, fn
      {[_identifier, _tags, _description] = line, _i}, acc ->
        %{acc | data: [line | acc.data]}

      {_line, _line_num} = bad_line, acc ->
        %{acc | malformed: [bad_line | acc.malformed]}
    end)
  end
end

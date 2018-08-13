defmodule Mix.NervesHubCLI.Shell do
  def info(output) do
    Mix.shell().info(output)
  end

  def error(output) do
    Mix.shell().error(output)
  end

  def raise(output) do
    Mix.raise(output)
  end

  def prompt(output) do
    Mix.shell().prompt(output)
  end

  def yes?(output) do
    Mix.shell().yes?(output)
  end

  def request_auth(prompt \\ "Local user password:") do
    password = password_get(prompt)

    case NervesHubCLI.User.auth(password) do
      {:ok, auth} ->
        auth

      :error ->
        __MODULE__.raise("Invalid password")
    end
  end

  # Password prompt that hides input by every 1ms
  # clearing the line with stderr
  def password_get(prompt) do
    password_clean(prompt)
    |> String.trim()
  end

  def render_error(errors) when is_list(errors) do
    Enum.each(errors, &render_error/1)
  end

  def render_error({error, reasons}) when is_list(reasons) do
    error("#{error}")
    for reason <- reasons, do: error("  #{reason}")
  end

  def render_error({:error, %{"status" => "forbidden"}}) do
    error("Invalid credentials")
    error("Your user certificate has either expired or has been revoked.")
    error("Please authenticate again:")
    error("  mix nerves_hub.user auth")
  end

  def render_error(error) do
    error("Unhandled error: #{inspect(error)}")
  end

  defp password_clean(prompt) do
    pid = spawn_link(fn -> loop(prompt) end)
    ref = make_ref()
    value = IO.gets(prompt <> " ")

    send(pid, {:done, self(), ref})
    receive do: ({:done, ^pid, ^ref} -> :ok)

    value
  end

  defp loop(prompt) do
    receive do
      {:done, parent, ref} ->
        send(parent, {:done, self(), ref})
        IO.write(:standard_error, "\e[2K\r")
    after
      1 ->
        IO.write(:standard_error, "\e[2K\r#{prompt} ")
        loop(prompt)
    end
  end
end

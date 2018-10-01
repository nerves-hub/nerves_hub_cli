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
    Mix.shell().prompt(output) |> String.trim()
  end

  def yes?(output) do
    System.get_env("NERVES_HUB_NON_INTERACTIVE") || Mix.shell().yes?(output)
  end

  def request_auth(prompt \\ "Local user password:") do
    env_cert = System.get_env("NERVES_HUB_CERT")
    env_key = System.get_env("NERVES_HUB_KEY")

    if env_cert != nil and env_key != nil do
      %{cert: env_cert, key: env_key}
    else
      password = password_get(prompt)

      case NervesHubCLI.User.auth(password) do
        {:ok, auth} ->
          auth

        :error ->
          __MODULE__.raise("Invalid password")
      end
    end
  end

  def request_keys(org, name, prompt \\ "Local key password: ") do
    env_pub_key = System.get_env("NERVES_HUB_FW_PRIVATE_KEY")
    env_priv_key = System.get_env("NERVES_HUB_FW_PUBLIC_KEY")

    if env_pub_key != nil and env_priv_key != nil do
      {:ok, env_pub_key, env_priv_key}
    else
      key_password = password_get(prompt)
      NervesHubCLI.Key.get(org, name, key_password)
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

  def render_error({:error, %{"status" => reason}}) do
    error(reason)
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

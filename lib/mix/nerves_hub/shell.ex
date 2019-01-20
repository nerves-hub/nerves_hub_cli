defmodule Mix.NervesHubCLI.Shell do
  def info(output) do
    Mix.shell().info(output)
  end

  def error(output) do
    Mix.shell().error(output)
  end

  @spec raise(String.t()) :: no_return()
  def raise(output) do
    Mix.raise(output)
  end

  def prompt(output) do
    Mix.shell().prompt(output) |> String.trim()
  end

  def yes?(output) do
    System.get_env("NERVES_HUB_NON_INTERACTIVE") || Mix.shell().yes?(output)
  end

  @spec request_auth(String.t()) :: NervesHubCore.Auth.t()
  def request_auth(prompt \\ "Local NervesHub user password:") do
    env_cert = System.get_env("NERVES_HUB_CERT")
    env_key = System.get_env("NERVES_HUB_KEY")

    if env_cert != nil and env_key != nil do
      env_cert = try_decode64(env_cert)
      env_key = try_decode64(env_key)

      %NervesHubCore.Auth{
        cert: X509.Certificate.from_pem!(env_cert),
        key: X509.PrivateKey.from_pem!(env_key)
      }
    else
      password = password_get(prompt)

      case NervesHubCLI.User.auth(password) do
        {:ok, auth} ->
          auth

        {:error, _} ->
          __MODULE__.raise("Invalid password")
      end
    end
  end

  def request_keys(org, name) do
    request_keys(org, name, "Local signing key password for '#{name}': ")
  end

  def request_keys(org, name, prompt) do
    env_pub_key = System.get_env("NERVES_HUB_FW_PRIVATE_KEY")
    env_priv_key = System.get_env("NERVES_HUB_FW_PUBLIC_KEY")

    if env_pub_key != nil and env_priv_key != nil do
      {:ok, env_priv_key, env_pub_key}
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

  @spec render_error([{:error, any()}]) :: no_return()
  def render_error(errors) do
    _ = do_render_error(errors)
    System.halt(1)
  end

  def do_render_error(errors) when is_list(errors) do
    Enum.each(errors, &do_render_error/1)
  end

  def do_render_error({error, reasons}) when is_list(reasons) do
    error("#{error}")
    for reason <- reasons, do: error("  #{reason}")
  end

  def do_render_error({:error, %{"status" => "forbidden"}}) do
    error("Invalid credentials")
    error("Your user certificate has either expired or has been revoked.")
    error("Please authenticate again:")
    error("  mix nerves_hub.user auth")
  end

  def do_render_error({:error, %{"status" => reason}}) do
    error(reason)
  end

  def do_render_error({:error, %{"errors" => reason}}) when is_binary(reason) do
    error(reason)
  end

  def do_render_error({:error, %{"errors" => reasons}}) when is_list(reasons) do
    error("HTTP error")
    for {key, reason} <- reasons, do: error("  #{key}: #{reason}")
  end

  def do_render_error(error) do
    error("Unhandled error: #{inspect(error)}")
  end

  defp try_decode64(value) do
    case Base.decode64(value) do
      {:ok, value} -> value
      _ -> value
    end
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

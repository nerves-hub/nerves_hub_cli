defmodule NervesHubCLI.Shell do
  @password_retries_allowed 3

  defexception [:message]

  @spec info(IO.ANSI.ansidata()) :: :ok
  def info(output) do
    IO.puts(IO.ANSI.format(output))
  end

  @spec error(IO.ANSI.ansidata()) :: :ok
  def error(output) do
    IO.puts(:stderr, IO.ANSI.format(red(output)))
  end

  @spec raise(String.t()) :: no_return()
  def raise(output) do
    raise(__MODULE__, output)
  end

  @spec prompt(String.t()) :: String.t()
  def prompt(output) do
    IO.gets(output <> " ") |> String.trim()
  end

  @spec yes?(String.t()) :: boolean()
  def yes?(message) do
    unless System.get_env("NERVES_HUB_NON_INTERACTIVE") do
      answer = IO.gets(message <> " [Yn] ")
      is_binary(answer) and String.trim(answer) in ["", "y", "Y", "yes", "YES", "Yes"]
    end
  end

  @spec request_auth(String.t()) :: NervesHubUserAPI.Auth.t()
  def request_auth(prompt \\ "Local NervesHub user password:") do
    env_cert = System.get_env("NERVES_HUB_CERT")
    env_key = System.get_env("NERVES_HUB_KEY")

    if env_cert != nil and env_key != nil do
      env_cert = try_decode64(env_cert)
      env_key = try_decode64(env_key)

      %NervesHubUserAPI.Auth{
        cert: X509.Certificate.from_pem!(env_cert),
        key: X509.PrivateKey.from_pem!(env_key)
      }
    else
      case request_password(prompt, @password_retries_allowed) do
        {:ok, auth} ->
          auth

        {:error, _} ->
          __MODULE__.raise("Invalid password")
      end
    end
  end

  def request_password(_prompt, 0) do
    {:error, :failed_password}
  end

  def request_password(prompt, count) do
    password = password_get(prompt)

    case NervesHubCLI.User.auth(password) do
      {:ok, auth} ->
        {:ok, auth}

      {:error, _} ->
        request_password("Please enter the password again:", count - 1)
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
  @spec password_get(String.t()) :: String.t()
  def password_get(prompt) do
    password_clean(prompt)
    |> String.trim()
  end

  @dialyzer [{:no_return, render_error: 1}, {:no_fail_call, render_error: 1}]

  @spec render_error([{:error, any()}] | {:error, any()}, boolean() | nil) ::
          :ok | no_return()
  def render_error(errors, halt? \\ true) do
    _ = do_render_error(errors)

    if halt? do
      System.halt(1)
    else
      :ok
    end
  end

  @spec do_render_error(any()) :: :ok
  def do_render_error(errors) when is_list(errors) do
    Enum.each(errors, &do_render_error/1)
  end

  def do_render_error({error, reasons}) when is_list(reasons) do
    error("#{error}")
    for reason <- reasons, do: error("  #{reason}")
    :ok
  end

  def do_render_error({:error, reason}) when is_binary(reason) do
    error(reason)
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
    :ok
  end

  def do_render_error(error) do
    error("Unhandled error: #{inspect(error)}")
  end

  defp try_decode64(value) do
    case Base.decode64(value, ignore: :whitespace) do
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

  defp red(message) do
    [:red, :bright, message]
  end
end

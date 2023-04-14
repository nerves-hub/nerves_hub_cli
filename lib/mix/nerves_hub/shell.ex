defmodule Mix.NervesHubCLI.Shell do
  alias Mix.NervesHubCLI.Utils

  @spec info(IO.ANSI.ansidata()) :: :ok
  def info(output) do
    Mix.shell().info(output)
  end

  @spec error(IO.ANSI.ansidata()) :: :ok
  def error(output) do
    Mix.shell().error(output)
  end

  @spec raise(String.t()) :: no_return()
  def raise(output) do
    Mix.raise(output)
  end

  @spec prompt(String.t()) :: String.t()
  def prompt(output) do
    Mix.shell().prompt(output) |> String.trim()
  end

  @spec yes?(String.t()) :: boolean()
  def yes?(message) do
    System.get_env("NERVES_HUB_NON_INTERACTIVE") || Mix.shell().yes?(message)
  end

  @spec request_auth() :: NervesHubCLI.API.Auth.t() | nil
  def request_auth() do
    if token = Utils.token() do
      %NervesHubCLI.API.Auth{token: token}
    end
  end

  def request_password(_prompt, 0) do
    {:error, :failed_password}
  end

  def request_keys(org, name) do
    request_keys(org, name, "Local signing key password for '#{name}': ")
  end

  def request_keys(org, name, prompt) do
    env_pub_key = System.get_env("NERVES_HUB_FW_PUBLIC_KEY")
    env_priv_key = System.get_env("NERVES_HUB_FW_PRIVATE_KEY")

    if env_pub_key != nil and env_priv_key != nil do
      {:ok, env_pub_key, env_priv_key}
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
    error("Your user token has either expired or has been revoked.")
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

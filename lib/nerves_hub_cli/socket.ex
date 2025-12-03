defmodule NervesHubCLI.Socket do
  @moduledoc """
  Phoenix Channels client for realtime updates.
  """

  use Slipstream,
    restart: :temporary

  require Logger

  @device_prefix "device:"

  def config(identifiers, auth_token) do
    %{
      config: %{url: "wss://nerves-hub.org/socket?token=#{auth_token}"},
      devices: identifiers
    }
  end

  def start_link(args) do
    Slipstream.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Slipstream
  def init(%{config: config, devices: devices}) do
    Logger.info("Init...")
    IO.inspect(config)

    socket =
      config
      |> connect!()
      |> assign(devices: devices)

    {:ok, socket}
  end

  @impl Slipstream
  def handle_connect(socket) do
    Logger.info("Handling connection...")

    socket =
      socket.assigns.devices
      |> Enum.reduce(socket, fn identifier, socket ->
        Logger.info("Joining device: #{identifier}")

        socket
        |> join(@device_prefix <> identifier)
      end)

    {:ok, socket}
  end

  @impl Slipstream
  def handle_join(any, join_response, socket) do
    # an asynchronous push with no reply:
    IO.puts("Channel joined: #{any}")
    IO.inspect(join_response, label: "Join response")

    {:ok, socket}
  end

  @impl Slipstream
  def handle_message(any, event, message, socket) do
    Logger.info("[#{any}] #{event}: #{inspect(message)}")

    {:ok, socket}
  end

  @impl Slipstream
  def handle_disconnect(_reason, socket) do
    Logger.info("Disconnected")
    {:stop, :normal, socket}
  end
end

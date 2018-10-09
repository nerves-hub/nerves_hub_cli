defmodule NervesHubCLI.User do
  alias NervesHubCLI.{Certificate, Crypto}

  @key "key.encrypted"
  @cert "cert.pem"

  def init() do
    data_dir()
    |> File.mkdir_p()
  end

  @spec save_certs(
          binary(),
          binary(),
          String.t()
        ) :: :ok | {:error, atom()}
  def save_certs(pem_cert, pem_key, certificate_password) do
    encrypted_key = Crypto.encrypt(pem_key, certificate_password)

    with :ok <- File.write(user_data_path(@cert), pem_cert),
         :ok <- File.write(user_data_path(@key), encrypted_key) do
      :ok
    else
      error ->
        deauth()
        error
    end
  end

  @spec auth(String.t()) :: {:error, atom()} | {:ok, %{cert: binary(), key: binary()}}
  def auth(password) do
    with {:ok, encrypted} <- File.read(user_data_path(@key)),
         {:ok, pem_key} <- Crypto.decrypt(encrypted, password),
         {:ok, pem_cert} <- File.read(user_data_path(@cert)) do
      key = Certificate.pem_to_der(pem_key)
      cert = Certificate.pem_to_der(pem_cert)

      {:ok, %{key: key, cert: cert}}
    end
  end

  @spec deauth() :: :ok
  def deauth() do
    File.rm(user_data_path(@cert))
    File.rm(user_data_path(@key))
    :ok
  end

  def ca_certs() do
    ca_cert_path =
      Application.get_env(:nerves_hub_cli, :ca_certs) || System.get_env("NERVES_HUB_CA_CERTS") ||
        :code.priv_dir(:nerves_hub_cli)
        |> to_string()
        |> Path.join("ca_certs")

    ca_cert_path
    |> File.ls!()
    |> Enum.map(&File.read!(Path.join(ca_cert_path, &1)))
    |> Enum.map(&Certificate.pem_to_der/1)
  end

  defp user_data_path(file) do
    Path.join(data_dir(), file)
  end

  defp data_dir() do
    Path.join(NervesHubCLI.home_dir(), "user_data")
  end
end

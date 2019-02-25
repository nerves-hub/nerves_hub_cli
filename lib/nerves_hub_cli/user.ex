defmodule NervesHubCLI.User do
  alias NervesHubCLI.Crypto
  alias X509.{Certificate, PrivateKey}

  @key "key.encrypted"
  @cert "cert.pem"

  def init() do
    data_dir()
    |> File.mkdir_p()
  end

  @spec save_certs(binary(), binary(), String.t()) :: :ok | {:error, atom()}
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

  @spec auth(String.t()) :: {:error, atom()} | {:ok, NervesHubUserAPI.Auth.t()}
  def auth(password) do
    with {:ok, encrypted} <- File.read(user_data_path(@key)),
         {:ok, pem_key} <- Crypto.decrypt(encrypted, password),
         key <- PrivateKey.from_pem!(pem_key),
         {:ok, pem_cert} <- File.read(user_data_path(@cert)),
         cert <- Certificate.from_pem!(pem_cert) do
      {:ok, %NervesHubUserAPI.Auth{key: key, cert: cert}}
    end
  end

  @spec deauth() :: :ok
  def deauth() do
    File.rm(user_data_path(@cert))
    File.rm(user_data_path(@key))
    :ok
  end

  defp user_data_path(file) do
    Path.join(data_dir(), file)
  end

  defp data_dir() do
    Path.join(NervesHubCLI.home_dir(), "user_data")
  end
end

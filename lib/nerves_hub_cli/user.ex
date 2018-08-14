defmodule NervesHubCLI.User do
  alias NervesHubCLI.{Certificate, Crypto}
  @env Mix.env()
  @key "key.encrypted"
  @csr "csr.pem"
  @cert "cert.pem"

  def init() do
    data_dir()
    |> File.mkdir_p()
  end

  def generate_csr(username, certificate_password) do
    # Create the data dir
    cert_files =
      data_dir()
      |> cert_files()

    with :ok <- Certificate.generate_key(cert_files[:key]),
         {:ok, key} <- File.read(cert_files[:key]),
         :ok <- Certificate.generate_csr(username, cert_files[:key], cert_files[:csr]),
         encrypted_key <- Crypto.encrypt(key, certificate_password),
         :ok <- File.write(cert_files[:key], encrypted_key) do
      File.read(cert_files[:csr])
    else
      error ->
        data_dir()
        |> cert_files()
        |> Enum.each(fn {_, file} -> File.rm(file) end)

        error
    end
  end

  def auth(password) do
    cert_files =
      data_dir()
      |> cert_files()

    with {:ok, encrypted} <- File.read(cert_files[:key]),
         {:ok, key} <- Crypto.decrypt(encrypted, password),
         {:ok, cert} <- File.read(cert_files[:cert]) do
      key = Certificate.pem_to_der(key)
      cert = Certificate.pem_to_der(cert)

      {:ok, %{key: key, cert: cert}}
    end
  end

  def deauth() do
    cert_files()
    |> Enum.each(fn {_, file} -> File.rm(file) end)
  end

  def ca_certs() do
    ca_cert_path =
      :code.priv_dir(:nerves_hub_cli)
      |> to_string()
      |> Path.join("ca_certs")
      |> Path.join(to_string(@env))

    ca_cert_path
    |> File.ls!()
    |> Enum.map(&File.read!(Path.join(ca_cert_path, &1)))
    |> Enum.map(&Certificate.pem_to_der/1)
  end

  def cert_files(path \\ nil) do
    path = path || data_dir()
    key = Path.join(path, @key)
    csr = Path.join(path, @csr)
    cert = Path.join(path, @cert)
    %{key: key, csr: csr, cert: cert}
  end

  defp data_dir() do
    Path.join([NervesHubCLI.home_dir(), "user_data"])
  end
end

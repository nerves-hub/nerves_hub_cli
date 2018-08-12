defmodule NervesHubCLI.Certificate do
  @spec generate_key(String.t()) :: :ok | {:error, binary()}
  def generate_key(key_file) do
    path = Path.dirname(key_file)

    ["ecparam", "-genkey", "-name", "prime256v1", "-noout", "-out", key_file]
    |> openssl(path)
  end

  @spec generate_csr(String.t(), String.t(), String.t()) :: :ok | {:error, binary()}
  def generate_csr(org, key_file, csr_file) do
    path = Path.dirname(csr_file)

    ["req", "-new", "-sha256", "-key", key_file, "-out", csr_file, "-subj", "/O=#{org}"]
    |> openssl(path)
  end

  def pem_to_der(<<"-----BEGIN", _rest::binary>> = cert) do
    [{_, cert, _}] = :public_key.pem_decode(cert)
    cert
  end

  def default_description() do
    case :inet.gethostname() do
      {:ok, hostname} -> to_string(hostname)
      {:error, _} -> "unknown"
    end
  end

  defp openssl(args, path) do
    path = path || File.cwd!()

    case System.cmd("openssl", args, stderr_to_stdout: true, cd: path) do
      {_output, 0} -> :ok
      {error, _} -> {:error, error}
    end
  end
end

defmodule NervesHubCLI.Certificate do
  def pem_to_der(<<"-----BEGIN", _rest::binary>> = cert) do
    [{_, cert, _}] = :public_key.pem_decode(cert)
    cert
  end

  @spec default_description() :: String.t()
  def default_description() do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end
end

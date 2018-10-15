defmodule NervesHubCLI.Certificate do
  def cert_from_pem(<<"-----BEGIN", _rest::binary>> = pem_cert) do
    X509.Certificate.from_pem(pem_cert)
  end

  def cert_to_der({:OTPCertificate, _, _, _} = cert) do
    X509.Certificate.to_der(cert)
  end

  def cert_to_pem({:OTPCertificate, _, _, _} = cert) do
    X509.Certificate.to_pem(cert)
  end

  def key_from_pem(<<"-----BEGIN", _rest::binary>> = pem_key) do
    X509.PrivateKey.from_pem(pem_key)
  end

  def key_to_der({:ECPrivateKey, _, _, _, _} = key) do
    X509.PrivateKey.to_der(key)
  end

  def key_to_pem({:ECPrivateKey, _, _, _, _} = key) do
    X509.PrivateKey.to_pem(key)
  end

  @spec default_description() :: String.t()
  def default_description() do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end
end

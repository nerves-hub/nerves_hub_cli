defmodule NervesHubCLI.Device do
  alias NervesHubCLI.Certificate

  def generate_csr(identifier, path) do
    key_path = Path.join(path, "#{identifier}-key.pem")
    csr_path = Path.join(path, "#{identifier}-csr.pem")

    with :ok <- Certificate.generate_key(key_path),
         :ok <- Certificate.generate_csr(identifier, key_path, csr_path) do
      File.read(csr_path)
    else
      error ->
        IO.inspect error
        error
    end
  end
end

defmodule NervesHubCLI.Crypto do
  @spec encrypt(String.t(), String.t(), String.t()) :: binary() | {:error, String.t()}
  def encrypt(plain_text, password, tag \\ "") do
    protected = %{
      alg: "PBES2-HS512",
      enc: "A256GCM",
      p2c: 4096,
      p2s: :crypto.strong_rand_bytes(32)
    }

    PBCS.encrypt({tag, plain_text}, protected, password: password)
  end

  @spec decrypt(binary(), any(), binary()) :: {:ok, binary()} | {:error, String.t()}
  def decrypt(cipher_text, password, tag \\ "") do
    case PBCS.decrypt({tag, cipher_text}, password: password) do
      plain_text when is_binary(plain_text) -> {:ok, plain_text}
      :error -> {:error, "unknown"}
      other -> other
    end
  end
end

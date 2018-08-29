defmodule NervesHubCLI.Crypto do
  def encrypt(plain_text, password, tag \\ "") do
    protected = %{
      alg: "PBES2-HS512",
      enc: "A256GCM",
      p2c: 4096,
      p2s: :crypto.strong_rand_bytes(32)
    }

    PBCS.encrypt({tag, plain_text}, protected, password: password)
  end

  def decrypt(cipher_text, password, tag \\ "") do
    PBCS.decrypt({tag, cipher_text}, password: password)
  end
end

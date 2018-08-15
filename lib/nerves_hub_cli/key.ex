defmodule NervesHubCLI.Key do
  alias NervesHubCLI.{Crypto, Cmd}

  @gen_file "fwup-key"

  @public_ext ".pub"
  @private_ext ".priv"

  def init() do
    data_dir()
    |> File.mkdir_p()
  end

  def create(key_name, key_password) do
    path = data_dir()

    tmp_dir = Path.join(path, "tmp")
    File.mkdir_p(tmp_dir)

    default_private_key_file = Path.join(tmp_dir, @gen_file <> @private_ext)
    default_public_key_file = Path.join(tmp_dir, @gen_file <> @public_ext)
    final_private_key = Path.join(path, key_name <> @private_ext)
    final_public_key = Path.join(path, key_name <> @public_ext)

    with :ok <- Cmd.fwup(["-g"], tmp_dir),
         {:ok, key} <- File.read(default_private_key_file),
         encrypted_key <- Crypto.encrypt(key, key_password),
         :ok <- File.write(default_private_key_file, encrypted_key),
         :ok <- File.cp(default_private_key_file, final_private_key),
         :ok <- File.cp(default_public_key_file, final_public_key) do
      File.rm_rf(tmp_dir)
      {:ok, final_public_key, final_private_key}
    else
      error ->
        File.rm_rf(tmp_dir)
        error
    end
  end

  def get(name, key_password) do
    path = data_dir()
    public_key_path = Path.join(path, name <> @public_ext)
    private_key_path = Path.join(path, name <> @private_ext)

    with {:ok, public_key} <- File.read(public_key_path),
         {:ok, encrypted_private_key} <- File.read(private_key_path),
         {:ok, private_key} <- Crypto.decrypt(encrypted_private_key, key_password) do
      {:ok, public_key, private_key}
    end
  end

  def delete(name) do
    path = data_dir()
    File.rm(Path.join(path, name <> @private_ext))
    File.rm(Path.join(path, name <> @public_ext))
  end

  def local_keys do
    path = data_dir()

    private_keys =
      path
      |> Path.join("*" <> @private_ext)
      |> Path.wildcard()

    private_key_names =
      private_keys
      |> Enum.map(&Path.basename(&1, private_ext()))
      |> MapSet.new()

    public_keys =
      path
      |> Path.join("*" <> @public_ext)
      |> Path.wildcard()

    public_key_names =
      public_keys
      |> Enum.map(&Path.basename(&1, public_ext()))
      |> MapSet.new()

    keypairs =
      MapSet.intersection(public_key_names, private_key_names)
      |> MapSet.to_list()

    Enum.map(keypairs, fn name ->
      {:ok, key} =
        Path.join(path, name <> @public_ext)
        |> File.read()

      %{name: name, key: key}
    end)
  end

  def exists?(name) do
    local_keys()
    |> Enum.any?(&(Map.get(&1, :name) == name))
  end

  def private_ext(), do: @private_ext
  def public_ext(), do: @public_ext

  defp data_dir() do
    Path.join([NervesHubCLI.home_dir(), "keys"])
  end
end

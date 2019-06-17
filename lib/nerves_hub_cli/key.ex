defmodule NervesHubCLI.Key do
  alias NervesHubCLI.{Crypto, Cmd}

  @gen_file "fwup-key"

  @public_ext ".pub"
  @private_ext ".priv"

  def create(org, key_name, key_password) do
    path = data_dir(org)
    File.mkdir_p(path)

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

  def import(org, key_name, key_password, public_key_file, private_key_file) do
    path = data_dir(org)
    File.mkdir_p(path)

    final_private_key = Path.join(path, key_name <> @private_ext)
    final_public_key = Path.join(path, key_name <> @public_ext)

    with {:ok, priv_key_bin} <- File.read(private_key_file),
         {:ok, pub_key_bin} <- File.read(public_key_file),
         {:ok, priv_key_val} <- maybe_base64(priv_key_bin),
         {:ok, pub_key_val} <- maybe_base64(pub_key_bin),
         encrypted_key <- Crypto.encrypt(priv_key_val, key_password),
         :ok <- File.write(final_private_key, encrypted_key),
         :ok <- File.write(final_public_key, pub_key_val) do
      {:ok, final_public_key, final_private_key}
    end
  end

  def get(org, name, key_password) do
    path = data_dir(org)
    public_key_path = Path.join(path, name <> @public_ext)
    private_key_path = Path.join(path, name <> @private_ext)

    with {:ok, public_key} <- File.read(public_key_path),
         {:ok, encrypted_private_key} <- File.read(private_key_path),
         {:ok, private_key} <- Crypto.decrypt(encrypted_private_key, key_password) do
      {:ok, public_key, private_key}
    else
      {:error, :enoent} ->
        {:error, "Couldn't find #{public_key_path} or #{private_key_path}"}

      error ->
        error
    end
  end

  def delete(org, name) do
    path = data_dir(org)
    File.rm(Path.join(path, name <> @private_ext))
    File.rm(Path.join(path, name <> @public_ext))
  end

  def local_keys(org) do
    path = data_dir(org)
    File.mkdir_p(path)

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

  def exists?(org, name) do
    local_keys(org)
    |> Enum.any?(&(Map.get(&1, :name) == name))
  end

  def private_ext(), do: @private_ext
  def public_ext(), do: @public_ext

  defp data_dir(org) do
    Path.join([NervesHubCLI.home_dir(), "keys", org])
  end

  # Used to validate a fwup key import.
  defp maybe_base64(bin) when is_binary(bin) do
    case Base.decode64(bin) do
      {:ok, _decoded} -> {:ok, bin}
      :error -> {:ok, Base.encode64(bin)}
    end
  end
end

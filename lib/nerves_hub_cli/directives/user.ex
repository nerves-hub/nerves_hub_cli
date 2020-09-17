defmodule NervesHubCLI.Directives.User do
  import NervesHubCLI.Utils

  alias NervesHubCLI.{User, Config}
  alias NervesHubCLI.Shell

  alias X509.{Certificate, PrivateKey, CSR}

  # @shortdoc "Manages your NervesHub user account"

  @moduledoc """
  Manage your NervesHub user account.

  Users are authenticated to the NervesHub API by supplying a valid
  client certificate with every request. User certificates can be generated
  and managed on https://www.nerves-hub.org/account/certificates

  NervesHub will look for the following files in the location of $NERVES_HUB_HOME

      ca.pem:       A file that contains all known NervesHub Certificate Authority
                    certificates needed to authenticate.
      user.pem:     A signed user account certificate.
      user-key.pem: The user account certificate private key.


  ## whoami

      nh user whoami

  ## register

      nh user register

  ## auth

      nh user auth

  ## deauth

      nh user deauth

  ## cert export

      nh user cert export

  ### Command-line options

    * `--path` - (Optional) A local location for exporting certificate.
  """

  @switches [path: :string]
  @data_dir "nerves-hub"

  def run(args) do
    _ = Application.ensure_all_started(:nerves_hub_cli)

    {opts, args} = OptionParser.parse!(args, strict: @switches)

    show_api_endpoint()

    case args do
      ["whoami"] ->
        whoami()

      ["register"] ->
        register()

      ["auth"] ->
        auth()

      ["deauth"] ->
        deauth()

      ["cert", "export"] ->
        cert_export(opts)

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.info("""


    Usage:

      nh user whoami
      nh user register
      nh user auth
      nh user deauth
      nh user cert export


    """)
  end

  def whoami do
    auth = Shell.request_auth()

    case NervesHubUserAPI.User.me(auth) do
      {:ok, %{"data" => data}} ->
        %{"username" => username, "email" => email} = data

        Shell.info("""
        username:  #{username}
        email: #{email}
        """)

      error ->
        Shell.render_error(error)
    end
  end

  def register() do
    email = Shell.prompt("Email address:") |> String.trim()
    username = Shell.prompt("Username:") |> String.trim()
    password = Shell.password_get("NervesHub password:") |> String.trim()
    confirm = Shell.password_get("NervesHub password (confirm):") |> String.trim()

    unless String.equivalent?(password, confirm) do
      Mix.raise("Entered passwords do not match")
    end

    Shell.info("Registering account...")

    register(username, email, password)
  end

  def auth() do
    username_or_email = Shell.prompt("Username or email address:") |> String.trim()
    password = Shell.password_get("NervesHub password:") |> String.trim()
    Shell.info("Authenticating...")

    case NervesHubUserAPI.User.auth(username_or_email, password) do
      {:ok, %{"data" => %{"email" => email, "username" => username}}} ->
        Shell.info("Success")
        generate_certificate(username, email, password)

      {:error, %{"errors" => errors}} ->
        Shell.error("Account authentication failed \n")
        Shell.render_error(errors)

      error ->
        Shell.render_error(error)
    end
  end

  def deauth() do
    if Shell.yes?("Deauthorize the current user?") do
      User.deauth()
    end
  end

  def cert_export(opts) do
    path = opts[:path] || Path.join(File.cwd!(), @data_dir)
    password = Shell.password_get("Local user password:")

    with :ok <- File.mkdir_p(path),
         {:ok, %{key: key, cert: cert}} <- User.auth(password),
         key_pem <- PrivateKey.to_pem(key),
         cert_pem <- Certificate.to_pem(cert),
         filename <- certs_tar_file_name(path),
         {:ok, tar} <- :erl_tar.open(to_charlist(filename), [:write, :compressed]),
         :ok <- :erl_tar.add(tar, {'cert.pem', cert_pem}, []),
         :ok <- :erl_tar.add(tar, {'key.pem', key_pem}, []),
         :ok <- :erl_tar.close(tar) do
      Shell.info("User certs exported to: #{filename}")
    else
      error -> Shell.render_error(error)
    end
  end

  defp certs_tar_file_name(path),
    do: Path.join(path, "nerves_hub-certs.tar.gz")

  defp register(username, email, account_password) do
    case NervesHubUserAPI.User.register(username, email, account_password) do
      {:ok, %{"data" => %{"email" => ^email, "username" => ^username}}} ->
        Shell.info("Account created")
        generate_certificate(username, email, account_password)

      {:error, %{"errors" => errors}} ->
        Shell.error("Account creation failed \n")
        Shell.render_error(errors)

      error ->
        Shell.render_error(error)
    end
  end

  defp generate_certificate(username, email, account_password) do
    Shell.info("")
    Shell.info("NervesHub uses client-side SSL certificates to authenticate CLI requests.")
    Shell.info("")
    Shell.info("The next step will create an SSL certificate and store it in your ")
    Shell.info("'~/.nerves-hub' directory. A password is required to protect it. This password")
    Shell.info("does not need to be your NervesHub password. It will never be sent to NervesHub")
    Shell.info("or any other computer. If you lose it, you will need to run")
    Shell.info("'nh user auth' and create a new certificate.")
    Shell.info("")

    local_password = Shell.password_get("Please enter a local password:")

    key = PrivateKey.new_ec(:secp256r1)
    pem_key = PrivateKey.to_pem(key)

    csr = CSR.new(key, "/O=#{username}")
    pem_csr = CSR.to_pem(csr)

    with safe_csr <- Base.encode64(pem_csr),
         description <- NervesHubCLI.default_description(),
         {:ok, %{"data" => %{"cert" => pem_cert}}} <-
           NervesHubUserAPI.User.sign(email, account_password, safe_csr, description),
         :ok <- User.save_certs(pem_cert, pem_key, local_password),
         :ok <- Config.put(:email, email),
         :ok <- Config.put(:org, username) do
      Shell.info("Certificate created successfully.")
    else
      error ->
        User.deauth()
        Shell.render_error(error)
    end
  end
end

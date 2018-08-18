defmodule Mix.Tasks.NervesHub.User do
  use Mix.Task

  alias NervesHubCLI.{API, User, Certificate, Config}
  alias Mix.NervesHubCLI.Shell

  @shortdoc "Manages your NervesHub user account"

  @moduledoc """
  Manage your NervesHub user account.

  Users are authenticated to the NervesHub API by supplying a valid
  client certificate with every request. User certificates can be generated
  and managed on https://www.nerves-hub.org/account/certificates

  NervesHub will look for the following files in the location of $NERVES_HUB_HOME
    
    ca.pem:       A file that containes all known NervesHub Certificate Authority 
                  certificates needed to authenticate.
    user.pem:     A signed user account certificate.
    user-key.pem: The user account certificate private key.


  ## whoami

    mix nerves_hub.user whoami
  """

  @switches []

  def run(args) do
    Application.ensure_all_started(:nerves_hub_cli)

    {_opts, args} = OptionParser.parse!(args, strict: @switches)

    case args do
      ["whoami"] ->
        whoami()

      ["register"] ->
        register()

      ["auth"] ->
        auth()

      ["deauth"] ->
        deauth()

      _ ->
        render_help()
    end
  end

  def render_help() do
    Shell.raise("""
    Invalid arguments

    Usage:
      
      mix nerves_hub.user whoami
      mix nerves_hub.user register
    """)
  end

  def whoami do
    auth = Shell.request_auth()

    case API.User.me(auth) do
      {:ok, %{"data" => data}} ->
        %{"name" => name, "email" => email} = data
        org = Config.get(:org)

        Mix.shell().info("""
        name:  #{name} 
        email: #{email}
        """)

      error ->
        Shell.render_error(error)
    end
  end

  def register() do
    username = Shell.prompt("Username:") |> String.trim()
    email = Shell.prompt("Email:") |> String.trim()
    password = Mix.Tasks.Hex.password_get("Account password:") |> String.trim()
    confirm = Mix.Tasks.Hex.password_get("Account password (confirm):") |> String.trim()

    unless String.equivalent?(password, confirm) do
      Mix.raise("Entered passwords do not match")
    end

    Shell.info("Registering account...")

    register(username, email, password)
  end

  def auth() do
    email = Shell.prompt("Email:") |> String.trim()
    password = Mix.Tasks.Hex.password_get("Account password:") |> String.trim()
    Shell.info("Authenticating...")

    case API.User.auth(email, password) do
      {:ok, %{"data" => %{"email" => ^email, "name" => username}}} ->
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
    end
  end

  defp register(username, email, account_password) do
    case API.User.register(username, email, account_password) do
      {:ok, %{"data" => %{"email" => ^email, "name" => ^username}}} ->
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
    Shell.info("NervesHub will generate an SSL certificate to authenticate your account.")

    Shell.info(
      "Please enter a local password you wish to use to encrypt your account certificate"
    )

    certificate_password = Shell.password_get("Local password:")

    with {:ok, csr} <- User.generate_csr(username, certificate_password),
         safe_csr <- Base.encode64(csr),
         description <- Certificate.default_description(),
         {:ok, %{"data" => %{"cert" => cert}}} <-
           API.User.sign(email, account_password, safe_csr, description),
         %{cert: cert_file} <- User.cert_files(),
         :ok <- File.write(cert_file, cert),
         :ok <- Config.put(:email, email),
         :ok <- Config.put(:org, username) do
      Shell.info("Finished")
    else
      error ->
        User.deauth()
        Shell.render_error(error)
    end
  end
end

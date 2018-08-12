defmodule NervesHubCLI.API.Deployment do
  alias NervesHubCLI.API

  def list(product_name, auth) do
    API.request(:get, "deployments", %{product_name: product_name}, auth)
  end

  def update(product_name, deployment_name, params, auth) do
    params = %{
      product_name: product_name,
      deployment: params
    }

    API.request(:put, "deployments/#{deployment_name}", params, auth)
  end
end

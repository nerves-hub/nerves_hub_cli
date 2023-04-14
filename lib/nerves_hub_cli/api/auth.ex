defmodule NervesHubCLI.API.Auth do
  defstruct token: nil

  @type t :: %__MODULE__{token: <<_::40>>}

  @spec new(keyword() | map()) :: NervesHubCLI.API.Auth.t()
  def new(opts) do
    %__MODULE__{
      token: opts[:token]
    }
  end
end

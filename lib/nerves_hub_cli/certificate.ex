defmodule NervesHubCLI.Certificate do
  import X509.Certificate.Extension
  alias X509.Certificate.{Template, Validity}

  @user_validity_years 1
  @device_validity_years 31
  @serial_number_bytes 20

  @hash :sha256

  def device_template(validity_years \\ @device_validity_years) do
    validity_years = validity_years || @device_validity_years

    %Template{
      serial: {:random, @serial_number_bytes},
      validity: years(validity_years),
      hash: @hash,
      extensions: [
        basic_constraints: basic_constraints(false),
        key_usage: key_usage([:digitalSignature, :keyEncipherment]),
        ext_key_usage: ext_key_usage([:clientAuth]),
        subject_key_identifier: true,
        authority_key_identifier: true
      ]
    }
    |> Template.new()
  end

  def user_template(validity_years \\ @user_validity_years) do
    validity_years = validity_years || @user_validity_years

    %Template{
      serial: {:random, @serial_number_bytes},
      validity: years(validity_years),
      hash: @hash,
      extensions: [
        basic_constraints: basic_constraints(false),
        key_usage: key_usage([:digitalSignature, :keyEncipherment]),
        ext_key_usage: ext_key_usage([:clientAuth]),
        subject_key_identifier: true,
        authority_key_identifier: true
      ]
    }
    |> Template.new()
  end

  # Helpers

  defp backdate(datetime, hours) do
    datetime
    |> DateTime.to_unix()
    |> Kernel.-(hours * 60 * 60)
    |> DateTime.from_unix!()
  end

  defp trim(datetime) do
    datetime
    |> Map.put(:minute, 0)
    |> Map.put(:second, 0)
    |> Map.put(:microsecond, {0, 0})
  end

  defp years(years) do
    now =
      DateTime.utc_now()
      |> trim()

    not_before = backdate(now, 1) |> trim()
    not_after = Map.put(now, :year, now.year + years)
    Validity.new(not_before, not_after)
  end
end

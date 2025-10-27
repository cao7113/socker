defmodule Mix.Tasks.Gen.Rsa do
  @moduledoc """
  Gen RSA pem
  """

  use Mix.Task

  @switches [
    bits: :integer,
    file: :string,
    format: :string
  ]

  @default_bits 2048

  def run(args) do
    {opts, _parsed, _invalid} =
      OptionParser.parse(args, switches: @switches, aliases: [b: :bits, f: :format])

    bits = Keyword.get(opts, :bits, @default_bits)
    format = Keyword.get(opts, :format, "pkcs8") |> String.to_atom()

    # timepart = System.unique_integer([:positive])
    timepart = DateTime.utc_now(:second) |> DateTime.to_iso8601() |> String.replace(~r/[\W]/, "")

    file =
      Keyword.get(opts, :file, "keys/rsa/#{timepart}")

    File.mkdir_p!(Path.dirname(file))

    opts = [bits: bits, format: format]
    %{public_key: pubk, private_key: privk} = Rsa.pem_keys(opts)

    File.write!("#{file}-pub.pem", pubk)
    priv_file = "#{file}-key.pem"
    File.write!(priv_file, privk)
    File.chmod!(priv_file, 0o600)
    Mix.shell().info("Write pem keys into #{file}*.pem")
  end
end

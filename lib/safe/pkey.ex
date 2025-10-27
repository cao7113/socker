defmodule Pkey do
  @moduledoc """
  public_key application

  The public_key application uses the Crypto application to perform cryptographic operations and the ASN-1 application to handle PKIX-ASN-1 specifications, hence these applications must be loaded for the public_key application to work.

  - https://www.erlang.org/doc/apps/public_key/public_key_app.html
  """

  require Record

  # https://github.com/erlang/otp/blob/master/lib/public_key/include/public_key.hrl
  @public_key_include_file "public_key/include/public_key.hrl"

  def inspect_cacert() do
    :public_key.cacerts_get()
    |> hd
    |> IO.inspect(limit: :infinity)

    # {:cert, <<48, 130, ...>>, {:OTPCertificate, {}}}
    nil
  end

  def cacerts, do: :public_key.cacerts_get()

  # {ok, PemBin} = file:read_file("dsa.pem")
  def parse_pem(pem_file \\ "keys/key.pem") do
    # Path.absname(pem_file)
    # # pem_file = File.read(pem_file)
    {:ok, pem_bin} = :file.read_file(pem_file)
    [dsa_entry] = :public_key.pem_decode(pem_bin)
    # dsa_entry
    :public_key.pem_entry_decode(dsa_entry)
  end

  def record_names do
    # require Record
    # Record.extract_all(from_lib: "public_key/include/public_key.hrl")
    Record.extract_all(from_lib: @public_key_include_file)
    |> Keyword.keys()
    |> Enum.sort()
  end
end

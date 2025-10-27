defmodule Ssl do
  @moduledoc """
  :ssl application helper

  The SSL application uses the Public_Key, Asn1 and Crypto application to handle public keys and encryption, hence these applications must be loaded for the SSL application to work.

  - https://www.erlang.org/doc/apps/ssl/ssl_app.html
  """

  @latest_tls "tlsv1.3"

  @doc """
  iex>  Ssl.connect!("baidu.com")
  """
  def connect!(addr) do
    #    1 > ssl:start(), ssl:connect("google.com", 443, [{verify, verify_peer},
    #                                                {cacerts, public_key:cacerts_get()}]).
    #  {ok,{sslsocket, [...]}}
    opts = [verify: :verify_peer, cacerts: :public_key.cacerts_get()]
    {:ok, sock} = :ssl.connect(addr |> String.to_charlist(), 443, opts)

    # {:sslsocket, #Port<0.24>, #PID<0.322.0>, #PID<0.321.0>, :gen_tcp, :tls_gen_connection, #Reference<0.2018.1052.81927>, :undefined}
    sock
  end

  def sign_algs(ver \\ @latest_tls, kind \\ :default) do
    # ssl:signature_algs(default, 'tlsv1.3').
    :ssl.signature_algs(kind, ver |> String.to_atom())
  end

  defdelegate versions, to: :ssl

  def cipher_suites(ver \\ @latest_tls, kind \\ :default) do
    :ssl.cipher_suites(kind, ver |> String.to_atom())
  end
end

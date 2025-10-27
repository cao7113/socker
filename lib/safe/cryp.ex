defmodule Cryp do
  @moduledoc """
  crypto app(a library application) helper

  - https://www.erlang.org/doc/apps/crypto/crypto_app.html
  """

  ## ECDSA
  # :crypto.generate_key(:eddsa, :ed25519)

  ## EdDSA better

  def supports, do: :crypto.supports()

  # [:hashs, :ciphers, :kems, :public_keys, :macs, :curves, :rsa_opts]
  def support_keys, do: :crypto.supports() |> Keyword.keys()

  def ciphers, do: :crypto.supports(:ciphers)
  def curves, do: :crypto.supports(:curves) |> Enum.sort()
  def has_curve?(curve \\ :secp256k1), do: curves() |> Enum.any?(fn c -> c == curve end)

  def public_keys, do: :crypto.supports(:public_keys) |> Enum.sort()
end

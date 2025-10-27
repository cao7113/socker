defmodule Rsa do
  @moduledoc """
  Rsa play

  todo
  -  write test suites

  - https://blog.differentpla.net/blog/2023/02/07/generate-rsa-key-erlang/
  """

  require Record

  # @min_bits 4096
  @min_bits 2048
  # standard RSA exponent
  # 选择公钥指数​：随机选择整数 e（通常取 65537，因其是素数且二进制形式仅含两个 1，便于模幂运算），要求 1<e<ϕ(n)且 gcd(e,ϕ(n))=1（e与 ϕ(n)互质）
  @pe 65537
  # PKCS#8​（Public-Key Cryptography Standards #8） 通用；PKCS#1仅针对RSA
  # :pkcs8 or :pkcs1
  @default_format :pkcs8
  # https://github.com/erlang/otp/blob/master/lib/public_key/include/public_key.hrl
  @public_key_include_file "public_key/include/public_key.hrl"
  # https://www.erlang.org/doc/apps/public_key/public_key.html#t:pki_asn1_type/0
  # -type pki_asn1_type() ::
  #           'Certificate' | 'RSAPrivateKey' | 'RSAPublicKey' | 'SubjectPublicKeyInfo' | 'DSAPrivateKey' |
  #           'DHParameter' | 'PrivateKeyInfo' | 'CertificationRequest' | 'ContentInfo' |
  #           'CertificateList' | 'ECPrivateKey' | 'OneAsymmetricKey' | 'EcpkParameters'.

  # Rsa.rsa_pub_key(modulus: 3)
  @record_mapping [
    {:algo_id, :AlgorithmIdentifier},
    # PKCS#1: RSA only
    {:rsa_pub_key, :RSAPublicKey},
    {:rsa_priv_key, :RSAPrivateKey},
    # PKCS#8: General key format
    {:pub_key_info, :SubjectPublicKeyInfo},
    {:priv_key_info, :PrivateKeyInfo}
  ]

  @record_mapping
  |> Enum.each(fn {k, v} ->
    Record.defrecord(k, v, Record.extract(v, from_lib: @public_key_include_file))
  end)

  @doc """
  iex>  Rsa.record_for :SubjectPublicKeyInfo
  """
  def record_for(k) when is_atom(k) do
    # Record.extract(:RSAPrivateKey, from_lib: "public_key/include/public_key.hrl")
    # [
    #   version: :undefined,
    #   modulus: :undefined,
    #   publicExponent: :undefined,
    #   privateExponent: :undefined,
    #   prime1: :undefined,
    #   prime2: :undefined,
    #   exponent1: :undefined,
    #   exponent2: :undefined,
    #   coefficient: :undefined,
    #   otherPrimeInfos: :asn1_NOVALUE
    # ]
    Record.extract(k, from_lib: @public_key_include_file)
  end

  def records do
    @record_mapping
    |> Keyword.values()
    |> Enum.map(fn k -> {k, record_for(k)} end)
  end

  @doc """
  Generate private key using :public_key.generate_key/1)
  NOTE: public key included in private-key

  $>    man openssl-genrsa
  $>    openssl genrsa -f4 2048
  iex>  :public_key.generate_key({:rsa, 2048, 65537})
  """
  def gen_private_key(opts \\ []) do
    # {:RSAPrivateKey, :"two-prime", [int,...8], :asn1_NOVALUE}
    %{bits: bits, public_exponent: pe} =
      default_opts()
      |> Keyword.merge(opts)
      |> Map.new()

    :public_key.generate_key({:rsa, bits, pe})
  end

  @doc """
  Parse key info in pem file
  $> openssl rsa -in priv.key -text -noout
  """
  def parse_key(file \\ "keys/test/dev.key") do
    {:ok, file_bin} = File.read(file)
    [pem_entry] = :public_key.pem_decode(file_bin)
    key = :public_key.pem_entry_decode(pem_entry)

    key
    |> tuple_size()
    |> case do
      3 -> rsa_pub_key(key) |> Keyword.put(:record, :public_key)
      11 -> rsa_priv_key(key) |> Keyword.put(:record, :private_key)
    end
  end

  def pem_keys(opts \\ []) do
    pk = get_private_key(opts)
    opts = Keyword.put_new(opts, :private_key, pk)

    %{
      public_key: pem_pub_key(opts),
      private_key: pem_priv_key(opts)
    }
  end

  def pem_pub_key(opts \\ []) do
    # https://github.com/erlang/otp/blob/master/lib/public_key/src/public_key.erl#L1282
    priv_key = get_private_key(opts)
    format = Keyword.get(opts, :format, @default_format)

    rsa_priv_key(
      modulus: modulus,
      publicExponent: pe
    ) = priv_key

    pub_key = rsa_pub_key(modulus: modulus, publicExponent: pe)

    {asn1_type, record} =
      case format do
        :pkcs1 ->
          {:RSAPublicKey, pub_key}

        _ ->
          # https://blog.differentpla.net/blog/2023/02/07/generate-rsa-key-erlang/#writing-the-public-key-as-pem-pkcs8
          # support pkcs#8
          # $> openssl rsa -text -noout -pubin -in keys/pub.key

          # public_key:der_encode('RSAPublicKey', RSAPublicKey)}
          der = :public_key.der_encode(:RSAPublicKey, pub_key)

          r =
            pub_key_info(
              # https://github.com/erlang/otp/blob/f9f74f58d77365880a74c2fe8fb8a6851f562afd/lib/public_key/include/public_key.hrl#L643
              # -define('rsaEncryption', {1,2,840,113549,1,1,1}).
              algorithm: algo_id(algorithm: {1, 2, 840, 113_549, 1, 1, 1}),
              subjectPublicKey: der
            )

          {:SubjectPublicKeyInfo, r}
      end

    entry = :public_key.pem_entry_encode(asn1_type, record)
    :public_key.pem_encode([entry])
  end

  # openssl rsa -in my.key -text -noout
  # https://github.com/erlang/otp/blob/master/lib/public_key/src/public_key.erl#L1282
  def pem_priv_key(opts \\ []) do
    priv_key = get_private_key(opts)
    format = Keyword.get(opts, :format, @default_format)

    {asn1_type, record} =
      case format do
        :pkcs1 ->
          {:RSAPrivateKey, priv_key}

        _ ->
          # der = :public_key.der_encode(:RSAPrivateKey, priv_key)

          # rsa_priv_key(version: version) = priv_key

          # r =
          #   priv_key_info(
          #     version: version,
          #     privateKeyAlgorithm: algo_id(algorithm: {1, 2, 840, 113_549, 1, 1, 1}),
          #     privateKey: der
          #     # attributes: :asn1_NOVALUE,
          #     # publicKey: :asn1_NOVALUE
          #   )

          # r |> dbg
          # {:PrivateKeyInfo, r}
          # direct use private key here!!!
          {:PrivateKeyInfo, priv_key}
      end

    entry = :public_key.pem_entry_encode(asn1_type, record)
    :public_key.pem_encode([entry])
  end

  def get_private_key(opts) do
    pk = Keyword.get(opts, :private_key)

    if pk do
      pk
    else
      gen_private_key(opts)
    end
  end

  def default_opts() do
    [
      bits: @min_bits,
      public_exponent: @pe
    ]
  end

  @doc """
  :public_key.generate_key/1 use :crypto.generate_key/2
  """
  def gen_key_pair(opts \\ []) do
    %{bits: bits, public_exponent: pe} =
      default_opts()
      |> Keyword.merge(opts)
      |> Map.new()

    {pubk, privk} = :crypto.generate_key(:rsa, {bits, pe})
    %{bits: bits, pe: pe, public_key: pubk, private_key: privk}
  end
end

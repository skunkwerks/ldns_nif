defmodule LDNS do
  @moduledoc """
  LDNS bindings for Elixir.
  """

  @on_load :load_nif

  def load_nif do
    path = :filename.join(:code.priv_dir(:ldns), "ldns_nif")
    :erlang.load_nif(path, 0)
  end

  @doc """
  Validates a DNS zone file.

  Takes a binary containing a zone file and returns :ok if valid,
  or {:error, error_type, line_number, error_message} if invalid.

  ## Examples

      iex> LDNS.validate("example.com. 3600 IN SOA ns1.example.com. admin.example.com. 1 3600 1800 604800 3600")
      :ok

      iex> LDNS.validate("example.com. 3600 IN SOA ns1.example.com.")
      {:error, :unknown_error, 1, "Syntax error, value expected"}

      iex> LDNS.validate("example.com. abc IN A 192.0.2.1")
      {:error, :rdata_error, 1, "Syntax error, could not parse the RR's rdata"}

      iex> LDNS.validate("example.com. 3600 IN INVALID 192.0.2.1")
      {:error, :rdata_error, 1, "Syntax error, could not parse the RR's rdata"}

      iex> LDNS.validate("example.com. 3600 IN A 256.256.256.256")
      {:error, :rdata_error, 1, "Syntax error, could not parse the RR's rdata"}

      iex> LDNS.validate(File.read!("test/invalid/bad.zone"))
      :ok

  """
  def validate(binary) when is_binary(binary) do
    binary |> ensure_trailing_newline() |> zone_validate()
  end

  @doc """
  Converts a DNS zone file to JSON format. The final JSON parsing is done
  using Jason library, after NIF processing.

  Takes a binary containing a zone file and returns {:ok, json_string} if
  successful, or {:error, error_type, line_number, error_message} if
  parsing fails.

  ## Examples

      iex> {:ok, json} = LDNS.to_json("example.org. 86400 IN SOA ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750")
      iex> is_binary(json)
      true
  """
  def to_json(zonefile) when is_binary(zonefile) do
    case zonefile |> ensure_trailing_newline() |> zone_to_map() do
      {:ok, map} -> {:ok, Jason.encode!(order_zone(map), pretty: true) <> "\n"}
      error -> error
    end
  end

  @doc ~S"""
  to_json!/1 allows easy piping of zonefile conversion and raises on error. Yolo.

  ## Examples

      LDNS.to_json!("example.org. 86400 IN SOA ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750") |> IO.puts()
      {
        "name": "example.org",
        "records": [
          {
            "name": "example.org",
            "type": "SOA",
            "ttl": 86400,
            "data": {
              "mname": "ns.cabal5.net",
              "rname": "root.example.org",
              "serial": 1601227221,
              "refresh": 86400,
              "retry": 7200,
              "expire": 3600000,
              "minimum": 1750
            }
          }
        ]
      }
      :ok

      iex> json = LDNS.to_json!("example.org. 86400 IN SOA ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750")
      iex> Jason.decode!(json)["name"]
      "example.org"
  """
  def to_json!(zonefile) when is_binary(zonefile) do
    {:ok, map} = zonefile |> ensure_trailing_newline() |> zone_to_map()
    Jason.encode!(order_zone(map), pretty: true) <> "\n"
  end

  @doc """
  Converts a JSON zone string to zone file format.

  Takes a JSON string (as produced by `to_json/1`) and returns `{:ok, zone}`
  where `zone` is a valid zone file string, or `{:error, reason}` on failure.

  The output is validated using `LDNS.validate/1` before returning.

  ## Examples

      iex> json = LDNS.to_json!("example.org. 86400 IN SOA ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750")
      iex> {:ok, zone} = LDNS.to_zone(json)
      iex> zone =~ "example.org."
      true

  """
  def to_zone(json) when is_binary(json) do
    with {:ok, %{"records" => records}} <- Jason.decode(json),
         {:ok, lines} <- records_to_lines(records),
         zone = lines |> Enum.join("\n") |> ensure_trailing_newline(),
         :ok <- validate(zone) do
      {:ok, zone}
    else
      {:ok, _} -> {:error, :invalid_json, "JSON must contain a 'records' key"}
      {:error, %Jason.DecodeError{} = err} -> {:error, :invalid_json, Exception.message(err)}
      error -> error
    end
  end

  defp records_to_lines(records) do
    Enum.reduce_while(records, {:ok, []}, fn rec, {:ok, acc} ->
      case LDNS.RR.to_line(rec) do
        {:ok, line} -> {:cont, {:ok, [line | acc]}}
        {:error, _, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, lines} -> {:ok, Enum.reverse(lines)}
      error -> error
    end
  end

  @doc """
  Converts a JSON zone string to zone file format, raising on error.

  ## Examples

      iex> json = LDNS.to_json!("example.org. 86400 IN SOA ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750")
      iex> zone = LDNS.to_zone!(json)
      iex> zone =~ "example.org."
      true

  """
  def to_zone!(json) when is_binary(json) do
    case to_zone(json) do
      {:ok, zone} -> zone
      {:error, type, msg} -> raise "to_zone failed (#{type}): #{msg}"
    end
  end

  @data_key_order %{
    "SOA" => ~w(mname rname serial refresh retry expire minimum),
    "A" => ~w(ip),
    "AAAA" => ~w(ip),
    "NS" => ~w(dname),
    "PTR" => ~w(dname),
    "CNAME" => ~w(dname),
    "DNAME" => ~w(dname),
    "MX" => ~w(preference exchange),
    "TXT" => ~w(txt),
    "SRV" => ~w(priority weight port target),
    "NAPTR" => ~w(order preference flags service regexp replacement),
    "DS" => ~w(key_tag algorithm digest_type digest),
    "SSHFP" => ~w(alg fptype fp),
    "RRSIG" =>
      ~w(type_covered alg labels original_ttl expiration inception key_tag signers_name signature),
    "NSEC" => ~w(next_domain types),
    "NSEC3" => ~w(hash_algorithm flags iterations salt next_hashed_owner types),
    "NSEC3PARAM" => ~w(hash_algorithm flags iterations salt),
    "DNSKEY" => ~w(flags protocol alg public_key),
    "TLSA" => ~w(usage selector matching_type certificate_data),
    "CAA" => ~w(flags tag value),
    "HINFO" => ~w(cpu os),
    "SPF" => ~w(txt),
    "LOC" => ~w(loc)
  }

  defp order_zone(map) do
    records = Enum.map(map["records"] || map[:records], &order_record/1)
    Jason.OrderedObject.new([{"name", map["name"] || map[:name]}, {"records", records}])
  end

  defp order_record(rec) do
    name = rec["name"] || rec[:name]
    type = rec["type"] || rec[:type]
    ttl = rec["ttl"] || rec[:ttl]
    data = rec["data"] || rec[:data]
    ordered_data = order_data(type, data)

    Jason.OrderedObject.new([
      {"name", name},
      {"type", type},
      {"ttl", ttl},
      {"data", ordered_data}
    ])
  end

  defp order_data(type, data) do
    case Map.get(@data_key_order, type) do
      nil ->
        data

      keys ->
        pairs =
          for k <- keys, Map.has_key?(data, k) or Map.has_key?(data, String.to_atom(k)) do
            v = Map.get(data, k) || Map.get(data, String.to_atom(k))
            {k, v}
          end

        Jason.OrderedObject.new(pairs)
    end
  end

  defp ensure_trailing_newline(binary) do
    if String.ends_with?(binary, "\n"), do: binary, else: binary <> "\n"
  end

  defp zone_validate(_binary) do
    :erlang.nif_error(:nif_not_loaded)
  end

  defp zone_to_map(_binary) do
    :erlang.nif_error(:nif_not_loaded)
  end
end

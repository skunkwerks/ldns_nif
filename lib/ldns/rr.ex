defmodule LDNS.RR do
  @moduledoc """
  Converts DNS record maps (from JSON) into zone file line strings.
  """

  @txt_split_size 72

  @doc """
  Converts a DNS record map into a zone file line string.

  Takes a map with string keys (`"name"`, `"type"`, `"ttl"`, `"data"`) and
  returns `{:ok, line}` where `line` is a tab-separated zone file entry,
  or `{:error, :unsupported_rr_type, message}` for unknown record types.

  ## Examples

      iex> LDNS.RR.to_line(%{"name" => "example.org", "type" => "A", "ttl" => 3600, "data" => %{"ip" => "1.2.3.4"}})
      {:ok, "example.org.\\t3600\\tIN\\tA\\t1.2.3.4"}

      iex> LDNS.RR.to_line(%{"name" => "example.org", "type" => "UNKNOWN", "ttl" => 3600, "data" => %{}})
      {:error, :unsupported_rr_type, "Unsupported RR type 'UNKNOWN' for name 'example.org'"}

  """
  def to_line(%{"name" => name, "type" => type, "ttl" => ttl, "data" => data}) do
    case rdata(type, data) do
      :unsupported ->
        {:error, :unsupported_rr_type,
         "Unsupported RR type '#{type}' for name '#{name}'"}

      rdata_str ->
        {:ok, "#{fqdn(name)}\t#{ttl}\tIN\t#{type}\t#{rdata_str}"}
    end
  end

  defp fqdn(name) do
    if String.ends_with?(name, "."), do: name, else: name <> "."
  end

  defp rdata("SOA", d) do
    "#{fqdn(d["mname"])} #{fqdn(d["rname"])} #{d["serial"]} #{d["refresh"]} #{d["retry"]} #{d["expire"]} #{d["minimum"]}"
  end

  defp rdata("A", d), do: d["ip"]

  defp rdata("AAAA", d), do: d["ip"]

  defp rdata("NS", d), do: fqdn(d["dname"])

  defp rdata("PTR", d), do: fqdn(d["dname"])

  defp rdata("CNAME", d), do: fqdn(d["dname"])

  defp rdata("DNAME", d), do: fqdn(d["dname"])

  defp rdata("MX", d), do: "#{d["preference"]} #{fqdn(d["exchange"])}"

  defp rdata("TXT", d), do: split_txt(d["txt"])

  defp rdata("SPF", d), do: split_txt(d["txt"])

  defp rdata("SRV", d) do
    "#{d["priority"]} #{d["weight"]} #{d["port"]} #{fqdn(d["target"])}"
  end

  defp rdata("NAPTR", d) do
    "#{d["order"]} #{d["preference"]} \"#{d["flags"]}\" \"#{d["service"]}\" \"#{d["regexp"]}\" #{fqdn(d["replacement"])}"
  end

  defp rdata("DS", d) do
    "#{d["key_tag"]} #{d["algorithm"]} #{d["digest_type"]} #{d["digest"]}"
  end

  defp rdata("SSHFP", d) do
    "#{d["alg"]} #{d["fptype"]} #{d["fp"]}"
  end

  defp rdata("RRSIG", d) do
    "#{d["type_covered"]} #{d["alg"]} #{d["labels"]} #{d["original_ttl"]} #{d["expiration"]} #{d["inception"]} #{d["key_tag"]} #{fqdn(d["signers_name"])} #{d["signature"]}"
  end

  defp rdata("NSEC", d) do
    "#{fqdn(d["next_domain"])} #{d["types"]}"
  end

  defp rdata("NSEC3", d) do
    "#{d["hash_algorithm"]} #{d["flags"]} #{d["iterations"]} #{d["salt"]} #{d["next_hashed_owner"]} #{d["types"]}"
  end

  defp rdata("NSEC3PARAM", d) do
    "#{d["hash_algorithm"]} #{d["flags"]} #{d["iterations"]} #{d["salt"]}"
  end

  defp rdata("DNSKEY", d) do
    "#{d["flags"]} #{d["protocol"]} #{d["alg"]} #{d["public_key"]}"
  end

  defp rdata("TLSA", d) do
    "#{d["usage"]} #{d["selector"]} #{d["matching_type"]} #{d["certificate_data"]}"
  end

  defp rdata("CAA", d) do
    "#{d["flags"]} #{d["tag"]} #{d["value"]}"
  end

  defp rdata("HINFO", d), do: "\"#{d["cpu"]}\" \"#{d["os"]}\""

  defp rdata("LOC", d), do: d["loc"]

  defp rdata(_type, _data), do: :unsupported

  defp split_txt(txt) when byte_size(txt) <= @txt_split_size do
    "\"#{txt}\""
  end

  defp split_txt(txt) do
    txt
    |> chunk_string(@txt_split_size)
    |> Enum.map_join(" ", &"\"#{&1}\"")
  end

  defp chunk_string(<<>>, _size), do: []

  defp chunk_string(str, size) when byte_size(str) <= size, do: [str]

  defp chunk_string(str, size) do
    <<chunk::binary-size(^size), rest::binary>> = str
    [chunk | chunk_string(rest, size)]
  end
end

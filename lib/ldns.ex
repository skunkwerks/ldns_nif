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

      iex> zone = "example.com. 3600 IN SOA ns1.example.com. admin.example.com. 1 3600 1800 604800 3600\\n"
      iex> LDNS.validate(zone)
      :ok

      # Invalid SOA record (missing required fields)
      iex> LDNS.validate("example.com. 3600 IN SOA ns1.example.com.\\n")
      {:error, :unknown_error, 1, "Syntax error, value expected"}

      # Invalid TTL value
      iex> LDNS.validate("example.com. abc IN A 192.0.2.1\\n")
      {:error, :rdata_error, 1, "Syntax error, could not parse the RR's rdata"}

      # Invalid record type
      iex> LDNS.validate("example.com. 3600 IN INVALID 192.0.2.1\\n")
      {:error, :rdata_error, 1, "Syntax error, could not parse the RR's rdata"}

      # Invalid IP address format
      iex> LDNS.validate("example.com. 3600 IN A 256.256.256.256\\n")
      {:error, :rdata_error, 1, "Syntax error, could not parse the RR's rdata"}

  """
  def validate(_binary) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Converts a DNS zone file to map format.

  Takes a binary containing a zone file and returns {:ok, map()} if
  successful, or {:error, error_type, line_number, error_message} if
  parsing fails.

  ## Examples

      iex> zonefile = "example.org.            86400   IN      SOA ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750"
      iex> {:ok, zone = %{}} = LDNS.to_map(zonefile)
      iex> is_binary(json)
      true
  """
  def to_map(_binary) do
    :erlang.nif_error(:nif_not_loaded)
  end
end

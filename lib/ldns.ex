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
  or {:error, line_number, error_message, error_type} if invalid.

  ## Examples

      iex> zone = "example.com. 3600 IN SOA ns1.example.com. admin.example.com. 1 3600 1800 604800 3600\\n"
      iex> LDNS.validate(zone)
      :ok

      # Invalid SOA record (missing required fields)
      iex> LDNS.validate("example.com. 3600 IN SOA ns1.example.com.\\n")
      {:error, 1, ~c"Syntax error, value expected", :unknown_error}

      # Invalid TTL value
      iex> LDNS.validate("example.com. abc IN A 192.0.2.1\\n")
      {:error, 1, ~c"Syntax error, could not parse the RR's rdata", :rdata_error}

      # Invalid record type
      iex> LDNS.validate("example.com. 3600 IN INVALID 192.0.2.1\\n")
      {:error, 1, ~c"Syntax error, could not parse the RR's rdata", :rdata_error}

      # Invalid IP address format
      iex> LDNS.validate("example.com. 3600 IN A 256.256.256.256\\n")
      {:error, 1, ~c"Syntax error, could not parse the RR's rdata", :rdata_error}

  """
  def validate(_binary) do
    :erlang.nif_error(:nif_not_loaded)
  end
end

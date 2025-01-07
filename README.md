# LDNS_nif

## Installation

Currently FreeBSD only. Requires:

- `dns/ldns`
- `lang/elixir` or `lang/elixir-devel`

```sh
$ mix local.hex --force --if-missing
$ mix do deps.get, compile
$ mix test --trace
```

## Usage

```elixir
iex(1)> zone = "example.org. 86400 IN SOA ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750"
 LDNS.validate(zone)
:ok

iex(2)> LDNS.validate("bad.zone.")
{:error, 0, ~c"Syntax error, could not parse the RR's TTL", :unknown_error}

iex(3)> LDNS.validate("bad.zone. 123 IN A 12345")
{:error, 0, ~c"Syntax error, could not parse the RR's rdata", :rdata_error} 
```

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ldns` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ldns, "~> 0.1.0"}
  ]
end
```


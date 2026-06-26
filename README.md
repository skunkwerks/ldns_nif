# LDNS_nif

## Installation

Currently FreeBSD only. Requires:

- `dns/ldns`
- `lang/elixir` or `lang/elixir-devel`

```sh
$ mix local.hex --force --if-missing
$ mix do deps.get + compile
$ mix test --trace
```

## Usage

```elixir
iex(1)> LDNS.validate("example.org. 86400 IN SOA ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750")
:ok

iex(2)> LDNS.validate("bad.zone.")
{:error, :unknown_error, 0, "Syntax error, could not parse the RR's TTL"}

iex(3)> LDNS.validate("bad.zone. 123 IN A 12345")
{:error, :rdata_error, 1, "Syntax error, could not parse the RR's rdata"}
```

> Note: `validate/1` only checks syntax. Semantic errors such as CNAME+A
> conflicts are not detected:
>
> ```elixir
> iex(4)> LDNS.validate(File.read!("test/invalid/bad.zone"))
> :ok
> ```

```elixir
iex(5)> LDNS.to_json!("example.org. 86400 IN SOA ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750") |> IO.puts()
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
```

Convert JSON back to a zone file:

```elixir
iex(6)> json = LDNS.to_json!("example.org. 86400 IN SOA ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750\nexample.org. 3600 IN A 1.2.3.4")
iex(7)> LDNS.to_zone!(json) |> IO.puts()
example.org.	86400	IN	SOA	ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750
example.org.	3600	IN	A	1.2.3.4
:ok
```

Round-trip produces identical output:

```elixir
iex(8)> zone = "example.org. 86400 IN SOA ns.cabal5.net. root.example.org. 1601227221 86400 7200 3600000 1750"
iex(9)> jsin = LDNS.to_json!(zone)
iex(10)> jsout = LDNS.to_zone!(jsin) |> LDNS.to_json!()
iex(11)> jsin == jsout
true
```

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ldns` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ldns, "~> 0.2"}
  ]
end
```


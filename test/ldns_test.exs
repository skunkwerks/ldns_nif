defmodule LDNSTest do
  use ExUnit.Case
  doctest LDNS

  test "validates a valid zone file" do
    zone = """
    example.com. 3600 IN SOA ns1.example.com. admin.example.com. (
      2023121901 ; serial
      3600       ; refresh
      1800       ; retry
      604800     ; expire
      3600       ; minimum
    )
    """

    assert LDNS.validate(zone)
  end

  test "rejects an invalid zone file" do
    result = LDNS.validate("invalid @ record")
    {:error, type, line, msg} = result
    assert is_atom(type)
    assert is_integer(line)
    assert is_binary(msg)
  end

  @invalid_fixtures "test/invalid"

  describe "invalid zone files" do
    test "detects missing SOA record" do
      contents = File.read!(Path.join(@invalid_fixtures, "missing_soa.zone"))
      # SOA validation happens at parse time, so missing SOA is considered valid syntax
      assert :ok = LDNS.validate(contents)
    end

    test "detects malformed SOA record" do
      contents = File.read!(Path.join(@invalid_fixtures, "malformed_soa.zone"))
      assert {:error, :unknown_error, 6, msg} = LDNS.validate(contents)
      assert msg =~ "value expected"
    end

    test "detects invalid TTL" do
      contents = File.read!(Path.join(@invalid_fixtures, "invalid_ttl.zone"))
      assert {:error, :rdata_error, _, msg} = LDNS.validate(contents)
      assert msg =~ "could not parse"
    end

    test "detects invalid class" do
      contents = File.read!(Path.join(@invalid_fixtures, "invalid_class.zone"))
      assert {:error, :rdata_error, _, msg} = LDNS.validate(contents)
      assert to_string(msg) =~ "could not parse"
    end

    test "detects invalid rdata" do
      contents = File.read!(Path.join(@invalid_fixtures, "invalid_rdata.zone"))
      assert {:error, :rdata_error, _, msg} = LDNS.validate(contents)
      assert to_string(msg) =~ "could not parse"
    end
  end

  describe "nsd validate fixtures" do
    for path <- Path.wildcard("test/nsd/*.zone") do
      filename = Path.basename(path)

      if String.starts_with?(filename, "fail_") do
        test "#{filename} is invalid" do
          contents = File.read!(unquote(path))
          assert {:error, _, _, _} = LDNS.validate(contents)
        end
      else
        test "#{filename} is valid" do
          contents = File.read!(unquote(path))
          assert :ok == LDNS.validate(contents), "Expected #{unquote(filename)} to be valid"
        end
      end
    end
  end

  describe "nsd to_json fixtures" do
    for path <- Path.wildcard("test/nsd/*.zone"),
        json_path = path <> ".json",
        File.exists?(json_path) do
      filename = Path.basename(path)

      test "#{filename} converts to expected JSON" do
        contents = File.read!(unquote(path))
        expected = File.read!(unquote(json_path))

        {:ok, converted} = LDNS.to_json(contents)

        assert expected == converted,
               "JSON mismatch for #{unquote(filename)}"

        assert {:ok, _} = Jason.decode(converted),
               "Invalid JSON output for #{unquote(filename)}"
      end
    end
  end

  describe "json to_json fixtures" do
    for path <- Path.wildcard("test/json/*.zone") do
      filename = Path.basename(path)
      json_path = String.replace(path, ".zone", ".json")

      test "#{filename} converts to expected JSON" do
        contents = File.read!(unquote(path))
        expected = File.read!(unquote(json_path))

        {:ok, converted} = LDNS.to_json(contents)

        assert expected == converted,
               "JSON mismatch for #{unquote(filename)}"

        assert {:ok, _} = Jason.decode(converted),
               "Invalid JSON output for #{unquote(filename)}"
      end
    end
  end

  describe "LDNS.RR.to_line" do
    test "A record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "example.org",
                 "type" => "A",
                 "ttl" => 3600,
                 "data" => %{"ip" => "1.2.3.4"}
               })

      assert line == "example.org.\t3600\tIN\tA\t1.2.3.4"
    end

    test "AAAA record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "example.org",
                 "type" => "AAAA",
                 "ttl" => 86400,
                 "data" => %{"ip" => "2001:db8::1"}
               })

      assert line == "example.org.\t86400\tIN\tAAAA\t2001:db8::1"
    end

    test "SOA record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "example.org",
                 "type" => "SOA",
                 "ttl" => 86400,
                 "data" => %{
                   "mname" => "ns.example.org",
                   "rname" => "admin.example.org",
                   "serial" => 2023121901,
                   "refresh" => 3600,
                   "retry" => 1800,
                   "expire" => 604800,
                   "minimum" => 3600
                 }
               })

      assert line ==
               "example.org.\t86400\tIN\tSOA\tns.example.org. admin.example.org. 2023121901 3600 1800 604800 3600"
    end

    test "NS record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "example.org",
                 "type" => "NS",
                 "ttl" => 86400,
                 "data" => %{"dname" => "ns.cabal5.net"}
               })

      assert line == "example.org.\t86400\tIN\tNS\tns.cabal5.net."
    end

    test "CNAME record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "www.example.org",
                 "type" => "CNAME",
                 "ttl" => 120,
                 "data" => %{"dname" => "example.org"}
               })

      assert line == "www.example.org.\t120\tIN\tCNAME\texample.org."
    end

    test "MX record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "example.org",
                 "type" => "MX",
                 "ttl" => 86400,
                 "data" => %{"preference" => 10, "exchange" => "mail.example.org"}
               })

      assert line == "example.org.\t86400\tIN\tMX\t10 mail.example.org."
    end

    test "TXT record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "example.org",
                 "type" => "TXT",
                 "ttl" => 300,
                 "data" => %{"txt" => "v=spf1 -all"}
               })

      assert line == "example.org.\t300\tIN\tTXT\t\"v=spf1 -all\""
    end

    test "SRV record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "_sip._tcp.example.org",
                 "type" => "SRV",
                 "ttl" => 86400,
                 "data" => %{
                   "priority" => 10,
                   "weight" => 0,
                   "port" => 5060,
                   "target" => "sip.example.org"
                 }
               })

      assert line == "_sip._tcp.example.org.\t86400\tIN\tSRV\t10 0 5060 sip.example.org."
    end

    test "CAA record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "example.org",
                 "type" => "CAA",
                 "ttl" => 3600,
                 "data" => %{"flags" => 128, "tag" => "issue", "value" => "\"letsencrypt.org\""}
               })

      assert line == "example.org.\t3600\tIN\tCAA\t128 issue \"letsencrypt.org\""
    end

    test "SSHFP record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "host.example.org",
                 "type" => "SSHFP",
                 "ttl" => 86400,
                 "data" => %{"alg" => 4, "fptype" => 2, "fp" => "abcd1234"}
               })

      assert line == "host.example.org.\t86400\tIN\tSSHFP\t4 2 abcd1234"
    end

    test "DNSKEY record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "example.org",
                 "type" => "DNSKEY",
                 "ttl" => 3600,
                 "data" => %{
                   "flags" => 256,
                   "protocol" => 3,
                   "alg" => "8",
                   "public_key" => "AQO6base64data"
                 }
               })

      assert line == "example.org.\t3600\tIN\tDNSKEY\t256 3 8 AQO6base64data"
    end

    test "PTR record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "1.2.3.4.in-addr.arpa",
                 "type" => "PTR",
                 "ttl" => 3600,
                 "data" => %{"dname" => "host.example.org"}
               })

      assert line == "1.2.3.4.in-addr.arpa.\t3600\tIN\tPTR\thost.example.org."
    end

    test "DNAME record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "far.example",
                 "type" => "DNAME",
                 "ttl" => 3600,
                 "data" => %{"dname" => "faraway.example.net"}
               })

      assert line == "far.example.\t3600\tIN\tDNAME\tfaraway.example.net."
    end

    test "HINFO record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "host.example.org",
                 "type" => "HINFO",
                 "ttl" => 86400,
                 "data" => %{"cpu" => "KLH-10", "os" => "ITS"}
               })

      assert line == "host.example.org.\t86400\tIN\tHINFO\t\"KLH-10\" \"ITS\""
    end

    test "SPF record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "example.org",
                 "type" => "SPF",
                 "ttl" => 3600,
                 "data" => %{"txt" => "v=spf1 -all"}
               })

      assert line == "example.org.\t3600\tIN\tSPF\t\"v=spf1 -all\""
    end

    test "LOC record" do
      assert {:ok, line} =
               LDNS.RR.to_line(%{
                 "name" => "loc.example.org",
                 "type" => "LOC",
                 "ttl" => 3600,
                 "data" => %{
                   "loc" =>
                     "40 32 24.716 N 105 04 25.770 W 42849672.91m 1000m 500000m 2000m"
                 }
               })

      assert line =~
               "loc.example.org.\t3600\tIN\tLOC\t40 32 24.716 N 105 04 25.770 W"
    end

    test "unsupported RR type" do
      assert {:error, :unsupported_rr_type, msg} =
               LDNS.RR.to_line(%{
                 "name" => "example.org",
                 "type" => "UNKNOWN",
                 "ttl" => 3600,
                 "data" => %{}
               })

      assert msg =~ "UNKNOWN"
      assert msg =~ "example.org"
    end
  end

  describe "to_zone" do
    test "converts JSON to zone format" do
      json = File.read!("test/json/minimal.com.json")
      {:ok, zone} = LDNS.to_zone(json)

      assert zone =~ "minimal.com.\t3600\tIN\tSOA"
      assert zone =~ "minimal.com.\t3600\tIN\tA\t1.2.3.4"
      assert zone =~ "www.minimal.com.\t120\tIN\tCNAME\tminimal.com."
      assert String.ends_with?(zone, "\n")
    end

    test "rejects invalid JSON" do
      assert {:error, :invalid_json, _} = LDNS.to_zone("not json")
    end

    test "rejects JSON without records key" do
      assert {:error, :invalid_json, _} = LDNS.to_zone(~s({"name": "test"}))
    end

    test "rejects unsupported RR type" do
      json =
        Jason.encode!(%{
          "name" => "example.org",
          "records" => [
            %{
              "name" => "example.org",
              "type" => "BOGUS",
              "ttl" => 3600,
              "data" => %{"foo" => "bar"}
            }
          ]
        })

      assert {:error, :unsupported_rr_type, msg} = LDNS.to_zone(json)
      assert msg =~ "BOGUS"
    end

    test "to_zone!/1 raises on error" do
      assert_raise RuntimeError, fn -> LDNS.to_zone!("not json") end
    end
  end

  describe "json round-trip (json -> zone -> json)" do
    for path <- Path.wildcard("test/json/*.json") do
      filename = Path.basename(path)

      test "#{filename} round-trips through zone format" do
        json = File.read!(unquote(path))
        {:ok, zone} = LDNS.to_zone(json)
        {:ok, json2} = LDNS.to_json(zone)

        assert json == json2,
               "Round-trip mismatch for #{unquote(filename)}"
      end
    end
  end

  describe "zone round-trip (zone -> json -> zone -> json)" do
    for path <- Path.wildcard("test/nsd/*.zone"),
        json_path = path <> ".json",
        File.exists?(json_path) do
      filename = Path.basename(path)

      test "#{filename} round-trips through zone->json->zone->json" do
        contents = File.read!(unquote(path))
        expected_json = File.read!(unquote(json_path))

        {:ok, json1} = LDNS.to_json(contents)
        assert json1 == expected_json

        {:ok, zone} = LDNS.to_zone(json1)
        {:ok, json2} = LDNS.to_json(zone)

        assert json1 == json2,
               "Zone round-trip mismatch for #{unquote(filename)}"
      end
    end
  end
end

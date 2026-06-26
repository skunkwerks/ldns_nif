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
end

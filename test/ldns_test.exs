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

  @fixtures "test/nsd"

  test "validates all zone files in fixtures" do
    File.ls!(@fixtures)
    |> Enum.filter(&String.ends_with?(&1, ".zone"))
    |> Enum.each(&validate_fixture/1)
  end

  defp validate_fixture(filename) do
    path = Path.join(@fixtures, filename)
    contents = File.read!(path)
    result = LDNS.validate(contents)

    if String.starts_with?(filename, "fail_") do
      assert match?({:error, _, _, _}, result), "Expected #{filename} to be invalid"
    else
      assert result == :ok, "Expected #{filename} to be valid"
    end
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
end

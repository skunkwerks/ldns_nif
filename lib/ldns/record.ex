defmodule LDNS.Record do
  @moduledoc """
  Represents a DNS record with standardized fields.
  """

  # record types, loosely based on RFC 1035 and later naming conventions
  # ensures that zones can be loaded with atom key names
  @type a :: :ip
  @type aaaa :: :ip
  @type cname :: :dname
  @type mx :: :preference | :exchange
  @type ns :: :nsdname
  @type rr :: :name | :type | :ttl | :data
  @type rrset :: :name | :type | :ttl | :records
  @type rrsig ::
          :type_covered
          | :alg
          | :labels
          | :original_ttl
          | :expiration
          | :inception
          | :key_tag
          | :signers_name
          | :signature
  @type soa :: :mname | :rname | :serial | :refresh | :retry | :expire | :minimum
  @type sshfp :: :alg | :fp_type | :fp
  @type srv :: :priority | :weight | :port | :target
  @type txt :: :text

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          ttl: non_neg_integer(),
          data: map()
        }

  defstruct [:name, :type, :ttl, :data]
end

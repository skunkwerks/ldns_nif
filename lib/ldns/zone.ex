defmodule LDNS.Zone do
  @moduledoc """
  Represents a DNS zone with a name and collection of records.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          records: [LDNS.Record.t()]
        }

  defstruct [:name, records: []]
end

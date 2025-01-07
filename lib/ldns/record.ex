defmodule LDNS.Record do
  @moduledoc """
  Represents a DNS record with standardized fields.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          ttl: non_neg_integer(),
          data: map()
        }

  defstruct [:name, :type, :ttl, :data]
end

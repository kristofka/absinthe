defmodule Absinthe.Phase.Blueprint do
  use Absinthe.Phase

  @moduledoc """
  This phase populates the `definitions`, `operations`,  `schema_definitions`, `directives`, and `fragments` fields of the blueprint by converting
  the `Absinte.Language.Document.t()` to appropriate drafts using the `Absinthe.Blueprint.Draft` protocol.

  See `Absinthe.Language.Document` for details.

  """

  alias Absinthe.{Blueprint, Phase, Language}

  @spec run(Blueprint.t(), Keyword.t()) :: {:ok, Blueprint.t()}
  def run(blueprint, options \\ [])
  def run(%Blueprint{input: %Language.Document{definitions: [_vals | _ ]} = input} = blueprint, _options ) do
    blueprint = Blueprint.Draft.convert(input, blueprint)

    {:ok, blueprint}
  end

  def run(%Blueprint{input: %Language.Document{definitions: []} } = blueprint, _options ) do
    {:ok, blueprint}
  end

  def run(%Blueprint{} = bp, _options) do
    errors = [{:error, %Phase.Error{message: "Invalid input", phase: __MODULE__}} | bp.execution.validation_errors]
    put_in(bp.execution.validation_errors, [errors])
  end
end

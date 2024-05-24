defmodule Absinthe.Phase.Init do
  @moduledoc """
  Initial phase that will initialize the blueprint 
  with the phases that will be run in the pipeline.
  It will also convert the input 
  (a `String.t()` or an `Absinthe.Language.Source.t()` ) 
  to a blueprint if it is not already a blueprint
  where the `input` field is set to that value.
  """

  use Absinthe.Phase

  alias Absinthe.{Blueprint, Language, Phase}

  @spec run(String.t() | Language.Source.t() | Blueprint.t(), Keyword.t()) ::
          {:record_phases, Blueprint.t(), (Blueprint.t(), list(Phase.t()) -> Blueprint.t())}
  def run(input, _options \\ []) do
    {:record_phases, make_blueprint(input),
     fn bp, phases ->
       %{bp | initial_phases: phases}
     end}
  end

  defp make_blueprint(%Absinthe.Blueprint{} = blueprint) do
    blueprint
  end

  defp make_blueprint(input) do
    %Blueprint{input: input}
  end
end

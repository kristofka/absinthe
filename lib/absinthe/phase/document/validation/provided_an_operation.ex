defmodule Absinthe.Phase.Document.Validation.ProvidedAnOperation do
  @moduledoc """
  This phase validates document to ensure that at least one operation is given in the `Absinthe.Blueprint`.
  If the `:jump_phases` option is set to `true`, validation errors will cause this phase to return a
  `{:jump, blueprint, abort_phase}` causing the pipeline to skip execution until to the `abort_phase` phase.
  """


  alias Absinthe.{Blueprint, Phase}

  use Absinthe.Phase

  @doc """
  Run the validation.
  """
  @spec run(Blueprint.t(), Keyword.t()) ::
          {:ok, Blueprint.t()} | {:jump, Blueprint.t(), Phase.t()}
  def run(input, options \\ []) do
    case {handle_node(input), Map.new(options)} do
      {%{flags: %{no_operations: _}} = result,
       %{jump_phases: true, validation_result_phase: abort_phase}} ->
        {:jump, result, abort_phase}

      {result, _} ->
        {:ok, result}
    end
  end

  # Check for operation without any operations
  @spec handle_node(Blueprint.t()) :: Blueprint.t()
  defp handle_node(%Blueprint{operations: []} = node) do
    node
    |> flag_invalid(:no_operations)
    |> put_error(error())
  end

  defp handle_node(node) do
    node
  end

  @doc """
  Generate an error message for the validation.
  """
  @spec error_message() :: String.t()
  def error_message do
    "No operations provided."
  end

  # Generate the error for the node
  @spec error() :: Phase.Error.t()
  defp error do
    %Phase.Error{
      phase: __MODULE__,
      message: error_message()
    }
  end
end

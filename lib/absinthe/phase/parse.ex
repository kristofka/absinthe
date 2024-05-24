defmodule Absinthe.Phase.Parse do
  @moduledoc """
  This phase will parse the `input` field of the `Absinthe.Blueprint.t()` which at this point is either a `String.t()` or an `Absinthe.Language.Source.t()`.

  If tokenizing and parsing the source is successful, the `input` field of the blueprint will be set to the parsed `Absinthe.Language.Document.t()`.

  If tokenizing or parsing fails, the `input` field of the blueprint will be set to `nil` and the `validation_errors` field
  of the execution  will be set to a list of `Absinthe.Phase.Error.t()` structs.

  Among other possible errors, this phase will verify that the number of tokens in the source does not exceed the limit set by the `:token_limit` option.

  If the `:jump_phases` option is set to `true`, parse errors will cause this phase to return a `{:jump, blueprint, abort_phase}` causing the pipeline to
  skip execution until to the `abort_phase` phase.
  In the default pipeline with the default options, the `abort_phase` is `Absinthe.Phase.Document.Result` and `jump_phases` is set to `true`.

  """

  use Absinthe.Phase

  alias Absinthe.{Blueprint, Language, Phase}

  @spec run(Language.Source.t() | %Blueprint{}, Keyword.t()) ::
          {:ok, Blueprint.t()} | {:jump, Blueprint.t(), Phase.t()} | {:error, Blueprint.t()}
  def run(input, options \\ [])

  def run(%Absinthe.Blueprint{} = blueprint, options) do
    case parse(blueprint.input, options) do
      {:ok, value} ->
        {:ok, %{blueprint | input: value}}

      {:error, error} ->
        blueprint
        |> add_validation_error(error)
        |> handle_error(Map.new(options))
    end
  end

  def run(input, options) do
    run(%Absinthe.Blueprint{input: input}, options)
  end

  @spec add_validation_error(Blueprint.t(), Phase.Error.t()) :: Blueprint.t()
  defp add_validation_error(bp, error) do
    put_in(bp.execution.validation_errors, [error])
  end

  @spec handle_error(Blueprint.t(), map()) ::
          {:jump, Blueprint.t(), Phase.t()} | {:error, Blueprint.t()}
  def handle_error(blueprint, %{jump_phases: true, result_phase: abort_phase}) do
    {:jump, blueprint, abort_phase}
  end

  def handle_error(blueprint, _) do
    {:error, blueprint}
  end

  @spec tokenize(binary, Keyword.t()) :: {:ok, [tuple]} | {:error, Phase.Error.t()}
  def tokenize(input, options \\ []) do
    case Absinthe.Lexer.tokenize(input, options) do
      {:error, rest, loc} ->
        {:error, format_raw_parse_error({:lexer, rest, loc})}

      {:error, :exceeded_token_limit} ->
        {:error, %Phase.Error{message: "Token limit exceeded", phase: __MODULE__}}

      other ->
        other
    end
  end

  @spec parse(binary | Language.Source.t(), Keyword.t()) ::
          {:ok, Language.Document.t()} | {:error, Phase.Error.t()}
  defp parse(input, options) when is_binary(input) do
    parse(%Language.Source{body: input}, options)
  end

  defp parse(input, options) do
    try do
      case tokenize(input.body, options) do
        {:ok, []} ->
          {:ok, %Language.Document{}}

        {:ok, tokens} ->
          case :absinthe_parser.parse(tokens) do
            {:ok, _doc} = result ->
              result

            {:error, raw_error} ->
              {:error, format_raw_parse_error(raw_error)}
          end

        {:error, %Phase.Error{}} = other ->
          other
      end
    rescue
      error ->
        {:error, format_raw_parse_error(error)}
    end
  end

  # errors in the yecc parser
  @spec format_raw_parse_error({{integer, integer}, :absinthe_parser, [charlist]}) ::
          Phase.Error.t()
  defp format_raw_parse_error({{line, column}, :absinthe_parser, msgs}) do
    message = msgs |> Enum.map(&to_string/1) |> Enum.join("")
    %Phase.Error{message: message, locations: [%{line: line, column: column}], phase: __MODULE__}
  end

  @spec format_raw_parse_error({integer, :absinthe_parser, [charlist]}) ::
          Phase.Error.t()
  defp format_raw_parse_error({line, :absinthe_parser, msgs}) do
    message = msgs |> Enum.map(&to_string/1) |> Enum.join("")
    %Phase.Error{message: message, locations: [%{line: line, column: 0}], phase: __MODULE__}
  end

  # error in the tokenizer
  @spec format_raw_parse_error({:lexer, String.t(), {line :: pos_integer, column :: pos_integer}}) ::
          Phase.Error.t()
  defp format_raw_parse_error({:lexer, rest, {line, column}}) do
    sample_slice = String.slice(rest, 0, 10)
    sample = if String.valid?(sample_slice), do: sample_slice, else: inspect(sample_slice)

    message = "Parsing failed at `#{sample}`"
    %Phase.Error{message: message, locations: [%{line: line, column: column}], phase: __MODULE__}
  end

  # exception in the tokenizer
  @unknown_error_msg "An unknown error occurred during parsing"
  @spec format_raw_parse_error(map) :: Phase.Error.t()
  defp format_raw_parse_error(%{} = error) do
    detail =
      if is_exception(error) do
        ": " <> Exception.message(error)
      else
        ""
      end

    %Phase.Error{message: @unknown_error_msg <> detail, phase: __MODULE__}
  end
end

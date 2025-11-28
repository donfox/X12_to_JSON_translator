defmodule X12ToJson.Converter do
  @moduledoc """
  Main converter module for X12 to JSON conversion
  """

  alias X12ToJson.Parser
  alias X12ToJson.Transformer

  def convert_file(input_file) do
    case File.read(input_file) do
      {:ok, content} ->
        convert_content(content)

      {:error, :enoent} ->
        {:error, "File '#{input_file}' not found"}

      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
    end
  end

  def convert_content(content) do
    parser = Parser.new(content) |> Parser.parse()
    result = Transformer.convert(parser)
    json = Jason.encode!(result, pretty: true)
    {:ok, json}
  rescue
    e in Jason.EncodeError ->
      {:error, "JSON encoding failed: #{Exception.message(e)}"}

    e ->
      # Log the full error for debugging
      require Logger
      Logger.error("Conversion failed: #{Exception.format(:error, e, __STACKTRACE__)}")
      {:error, "Conversion failed: #{Exception.message(e)}"}
  end
end

#!/usr/bin/env elixir

# Add the library path if running as a script
Mix.install([{:jason, "~> 1.4"}])

Code.prepend_path("_build/dev/lib/x12_to_json/ebin")

defmodule X12ToJSON.ScriptRunner do
  @moduledoc """
  Script runner for X12 to JSON conversion using the X12ToJson library

  This script uses the library modules instead of duplicating code:
  - X12ToJson.Parser for parsing
  - X12ToJson.Transformer for transformation
  - X12ToJson.Converter for the main conversion logic
  """

  def main(args) do
    case args do
      [] ->
        print_usage()
        System.halt(1)

      [input_file] ->
        convert_and_print(input_file)

      [input_file, output_file] ->
        convert_and_save(input_file, output_file)

      _ ->
        IO.puts("Error: Too many arguments")
        print_usage()
        System.halt(1)
    end
  end

  defp print_usage do
    IO.puts("""
    Usage: elixir X12_837p_to_json_semantic.exs <input_file.x12> [output_file.json]

    Examples:
      elixir X12_837p_to_json_semantic.exs sample_837p_claim.x12
      elixir X12_837p_to_json_semantic.exs sample_837p_claim.x12 output.json

    Note: This script uses the X12ToJson library modules.
          For production use, compile with mix and use the escript.
    """)
  end

  defp convert_and_print(input_file) do
    case convert_file(input_file) do
      {:ok, json} ->
        IO.puts(json)

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end

  defp convert_and_save(input_file, output_file) do
    case convert_file(input_file) do
      {:ok, json} ->
        case File.write(output_file, json) do
          :ok ->
            IO.puts("Successfully converted #{input_file} to #{output_file}")

          {:error, reason} ->
            IO.puts("Error writing output file: #{inspect(reason)}")
            System.halt(1)
        end

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end

  defp convert_file(input_file) do
    # Try to use the library if available
    if Code.ensure_loaded?(X12ToJson.Converter) do
      X12ToJson.Converter.convert_file(input_file)
    else
      # Fallback for standalone script execution
      case File.read(input_file) do
        {:ok, content} ->
          convert_content_fallback(content)

        {:error, :enoent} ->
          {:error, "File '#{input_file}' not found"}

        {:error, reason} ->
          {:error, "Failed to read file: #{inspect(reason)}"}
      end
    end
  end

  # Fallback implementation using inline modules when library is not available
  defp convert_content_fallback(content) do
    IO.puts("""
    Warning: X12ToJson library not found. Using fallback implementation.
    For better performance, run from the project directory with: mix run
    """)

    # This would need the full implementation or we suggest using the library
    {:error, "Please run this from the elixir_project directory or use the compiled library"}
  end
end

# Run the script
X12ToJSON.ScriptRunner.main(System.argv())

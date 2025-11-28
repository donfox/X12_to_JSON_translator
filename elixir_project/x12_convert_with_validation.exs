#!/usr/bin/env elixir

defmodule X12.ConvertWithValidation do
  @moduledoc """
  X12 837P Converter with Validation
  Validates X12 file before conversion to prevent processing malformed data
  """

  def main(args) do
    case args do
      [] ->
        print_usage()
        System.halt(1)

      [input_file] ->
        validate_and_convert(input_file, nil)

      [input_file, output_file] ->
        validate_and_convert(input_file, output_file)

      _ ->
        IO.puts("Error: Too many arguments")
        print_usage()
        System.halt(1)
    end
  end

  defp validate_and_convert(input_file, output_file) do
    # Step 1: Validate the file
    IO.puts("Step 1: Validating #{input_file}...")

    case System.cmd("elixir", ["x12_validator.exs", input_file], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✓ Validation passed\n")
        # Step 2: Convert the file
        convert_file(input_file, output_file)

      {output, 1} ->
        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("VALIDATION FAILED - File contains errors")
        IO.puts(String.duplicate("=", 80))
        IO.puts("\nThe X12 file has validation errors and should not be converted.")
        IO.puts("Please fix the errors before conversion.\n")
        IO.puts("Validation output:")
        IO.puts(output)
        System.halt(1)

      {output, _} ->
        IO.puts("Error running validator: #{output}")
        System.halt(1)
    end
  end

  defp convert_file(input_file, nil) do
    IO.puts("Step 2: Converting #{input_file} to JSON...")

    case System.cmd("elixir", ["X12_837p_to_json_semantic.exs", input_file],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        IO.puts(output)
        System.halt(0)

      {output, code} ->
        IO.puts(output)
        System.halt(code)
    end
  end

  defp convert_file(input_file, output_file) do
    IO.puts("Step 2: Converting #{input_file} to JSON...")

    case System.cmd("elixir", ["X12_837p_to_json_semantic.exs", input_file, output_file],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        IO.puts(output)
        System.halt(0)

      {output, code} ->
        IO.puts(output)
        System.halt(code)
    end
  end

  defp print_usage do
    IO.puts("""

    X12 837P Converter with Validation

    This script validates the X12 file before conversion to ensure data quality.

    Usage: elixir x12_convert_with_validation.exs <input_file.x12> [output_file.json]

    Examples:
      elixir x12_convert_with_validation.exs sample_837p_claim.x12
      elixir x12_convert_with_validation.exs sample_837p_claim.x12 output.json

    The script will:
    1. Validate the X12 file for errors
    2. Only convert if validation passes
    3. Prevent processing of malformed data

    To skip validation (not recommended):
      elixir X12_837p_to_json_semantic.exs <input_file.x12> [output_file.json]
    """)
  end
end

# Run the main function
X12.ConvertWithValidation.main(System.argv())

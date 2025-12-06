defmodule X12ToJson.CLI do
  @moduledoc """
  Command-line interface for X12 to JSON converter
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
    IO.puts("Usage: x12_to_json <input_file.x12> [output_file.json]")
    IO.puts("\nExample:")
    IO.puts("  x12_to_json sample_837p_claim.x12")
    IO.puts("  x12_to_json sample_837p_claim.x12 output.json")
  end

  defp convert_and_print(input_file) do
    case X12ToJson.Converter.convert_file(input_file) do
      {:ok, json} ->
        IO.puts(json)

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end

  defp convert_and_save(input_file, output_file) do
    case X12ToJson.Converter.convert_file(input_file) do
      {:ok, json} ->
        case File.write(output_file, json) do
          :ok ->
            IO.puts("Successfully converted #{input_file} to #{output_file}")

          {:error, reason} ->
            IO.puts("Error writing output file: #{reason}")
            System.halt(1)
        end

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end
end

defmodule X12ToJson.Helpers do
  @moduledoc """
  Helper functions for X12 to JSON conversion
  """

  def get_element(nil, _), do: nil
  def get_element(list, index) when is_list(list) do
    Enum.at(list, index)
  end

  def format_date(nil), do: nil
  def format_date(""), do: nil
  def format_date(date_str) when is_binary(date_str) and byte_size(date_str) >= 8 do
    year = String.slice(date_str, 0, 4)
    month = String.slice(date_str, 4, 2)
    day = String.slice(date_str, 6, 2)
    "#{year}-#{month}-#{day}"
  end
  def format_date(_), do: nil

  def format_time(nil), do: nil
  def format_time(""), do: nil
  def format_time(time_str) when is_binary(time_str) and byte_size(time_str) >= 4 do
    hour = String.slice(time_str, 0, 2)
    minute = String.slice(time_str, 2, 2)
    "#{hour}:#{minute}"
  end
  def format_time(_), do: nil

  def parse_float(nil), do: nil
  def parse_float(""), do: nil
  def parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {float, _} -> float
      :error -> nil
    end
  end

  def parse_int(nil), do: nil
  def parse_int(""), do: nil
  def parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end

  def decode_payer_responsibility("P"), do: "Primary"
  def decode_payer_responsibility("S"), do: "Secondary"
  def decode_payer_responsibility("T"), do: "Tertiary"
  def decode_payer_responsibility(code), do: code

  def get_procedure_description("99213"), do: "Office/outpatient visit, established patient"
  def get_procedure_description("80053"), do: "Comprehensive metabolic panel"
  def get_procedure_description("85025"), do: "Complete blood count"
  def get_procedure_description(_), do: ""
end

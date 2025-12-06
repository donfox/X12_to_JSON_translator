#!/usr/bin/env elixir

defmodule X12.Validator do
  @moduledoc """
  X12 837P EDI Validator

  Validates X12 837P (Professional Claims) EDI files for:
  - Structural integrity (segment format, delimiters, envelopes)
  - Syntactical correctness (data types, lengths, code sets)
  - Business rules (required segments, relationships, logic)

  Usage:
      elixir x12_validator.exs <path_to_x12_file>

  Author: Healthcare Data Processing System
  Date: 2025-11-27
  """

  # Validation constants
  @min_valid_year 1900
  @max_valid_year 2100
  @min_isa_length 106
  @rounding_tolerance 0.01

  defmodule ValidationIssue do
    @moduledoc "Represents a single validation issue"
    defstruct [:level, :segment_id, :segment_number, :element_position, :message, :context]

    @type level :: :error | :warning | :info
    @type t :: %__MODULE__{
            level: level(),
            segment_id: String.t(),
            segment_number: non_neg_integer(),
            element_position: non_neg_integer() | nil,
            message: String.t(),
            context: String.t()
          }
  end

  defmodule ValidationResult do
    @moduledoc "Contains all validation results for an X12 file"
    defstruct valid?: true, issues: [], segment_count: 0

    @type t :: %__MODULE__{
            valid?: boolean(),
            issues: list(ValidationIssue.t()),
            segment_count: non_neg_integer()
          }

    def add_issue(result, level, segment_id, segment_num, element_pos, message, context \\ "") do
      issue = %ValidationIssue{
        level: level,
        segment_id: segment_id,
        segment_number: segment_num,
        element_position: element_pos,
        message: message,
        context: context
      }

      %{result | 
        issues: [issue | result.issues],
        valid?: if(level == :error, do: false, else: result.valid?)
      }
    end

    def get_summary(%{issues: issues}) do
      Enum.reduce(issues, %{error: 0, warning: 0, info: 0}, fn issue, acc ->
        Map.update!(acc, issue.level, &(&1 + 1))
      end)
    end
  end

  # X12 837P Configuration
  @valid_segments ~w(ISA GS ST BHT REF NM1 N3 N4 PER HL PRV SBR PAT CLM DTP CL1 HI LX SV1 SE GE IEA DMG)

  @entity_type_codes %{"1" => "Person", "2" => "Non-Person Entity"}
  @entity_id_codes %{
    "1P" => "Provider",
    "2B" => "Third-Party Administrator",
    "36" => "Employer",
    "40" => "Receiver",
    "41" => "Submitter",
    "85" => "Billing Provider",
    "87" => "Pay-to Provider",
    "IL" => "Insured",
    "PR" => "Payer",
    "QC" => "Patient"
  }

  @doc """
  Validate an X12 837P file
  """
  def validate_file(filepath) do
    case File.read(filepath) do
      {:ok, content} ->
        do_validation(content)

      {:error, :enoent} ->
        %ValidationResult{}
        |> ValidationResult.add_issue(:error, "FILE", 0, nil, "File not found: #{filepath}")

      {:error, reason} ->
        %ValidationResult{}
        |> ValidationResult.add_issue(:error, "FILE", 0, nil, "Error reading file: #{inspect(reason)}")
    end
  end

  defp do_validation(content) do
    with {:ok, delimiters} <- parse_delimiters(content),
         {:ok, segments} <- split_segments(content, delimiters) do
      result = %ValidationResult{segment_count: length(segments)}

      result
      |> validate_structure(segments)
      |> validate_envelopes(segments, delimiters)
      |> validate_segments(segments, delimiters)
      |> validate_business_rules(segments, delimiters)
    else
      {:error, message} ->
        %ValidationResult{}
        |> ValidationResult.add_issue(:error, "FILE", 0, nil, message)
    end
  end

  # Parse delimiters from ISA segment
  defp parse_delimiters(content) when byte_size(content) < @min_isa_length do
    {:error, "File too short to contain valid ISA segment"}
  end

  defp parse_delimiters(content) do
    if String.starts_with?(content, "ISA") do
      element_sep = String.at(content, 3)
      sub_element_sep = String.at(content, 104)
      
      # Find segment terminator (typically ~ at end of ISA)
      isa_segment = content
                    |> String.split("\n", parts: 2)
                    |> List.first()
                    |> String.trim()
      
      segment_term = String.last(isa_segment)

      {:ok, %{
        element: element_sep,
        sub_element: sub_element_sep,
        segment: segment_term
      }}
    else
      {:error, "File must start with ISA segment"}
    end
  end

  # Split content into segments and elements
  defp split_segments(content, %{segment: segment_term, element: element_sep}) do
    segments = 
      content
      |> String.split(segment_term, trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(String.length(&1) > 0))
      |> Enum.map(&String.split(&1, element_sep))
    
    {:ok, segments}
  end

  # Validate basic structural requirements
  defp validate_structure(result, segments) do
    segments
    |> Enum.with_index(1)
    |> Enum.reduce(result, fn {segment, idx}, acc ->
      segment_id = List.first(segment) || ""

      cond do
        segment_id == "" ->
          ValidationResult.add_issue(acc, :error, "UNKNOWN", idx, nil, "Segment has no identifier")

        segment_id not in @valid_segments ->
          ValidationResult.add_issue(
            acc,
            :warning,
            segment_id,
            idx,
            nil,
            "Segment ID '#{segment_id}' not recognized for 837P transaction"
          )

        length(segment) < 2 ->
          ValidationResult.add_issue(
            acc,
            :error,
            segment_id,
            idx,
            nil,
            "Segment has insufficient elements (found #{length(segment)})"
          )

        true ->
          acc
      end
    end)
  end

  # Validate ISA/IEA, GS/GE, ST/SE envelope structure
  defp validate_envelopes(result, segments, _delimiters) do
    envelope_state = %{
      isa_count: 0,
      gs_count: 0,
      st_count: 0,
      isa_control: nil,
      gs_control: nil,
      st_control: nil
    }

    {final_result, final_state} = 
      segments
      |> Enum.with_index(1)
      |> Enum.reduce({result, envelope_state}, fn {segment, idx}, {acc_result, state} ->
        segment_id = List.first(segment) || ""
        validate_envelope_segment(acc_result, state, segment, segment_id, idx)
      end)

    # Verify we have required envelopes
    final_result
    |> check_required_envelope(final_state.isa_count, "ISA")
    |> check_required_envelope(final_state.gs_count, "GS")
    |> check_required_envelope(final_state.st_count, "ST")
  end

  defp validate_envelope_segment(result, state, segment, segment_id, idx) do
    case segment_id do
      "ISA" ->
        new_state = %{state | isa_count: state.isa_count + 1}
        new_result = if state.isa_count > 0 do
          ValidationResult.add_issue(result, :error, "ISA", idx, nil, "Multiple ISA segments found")
        else
          result
        end

        control = Enum.at(segment, 13)
        {new_result, %{new_state | isa_control: control}}

      "IEA" ->
        iea_control = Enum.at(segment, 2)
        expected_gs = Enum.at(segment, 1)

        new_result = result
        |> check_control_match(state.isa_control, iea_control, "IEA", "ISA", idx, 2)
        |> check_count_match(expected_gs, state.gs_count, "IEA", "functional groups", idx, 1)

        {new_result, state}

      "GS" ->
        control = Enum.at(segment, 6)
        {result, %{state | gs_count: state.gs_count + 1, gs_control: control}}

      "GE" ->
        ge_control = Enum.at(segment, 2)
        expected_st = Enum.at(segment, 1)

        new_result = result
        |> check_control_match(state.gs_control, ge_control, "GE", "GS", idx, 2)
        |> check_count_match(expected_st, state.st_count, "GE", "transaction sets", idx, 1)

        {new_result, state}

      "ST" ->
        new_state = %{state | st_count: state.st_count + 1}
        control = Enum.at(segment, 2)
        transaction_id = Enum.at(segment, 1)

        new_result = if transaction_id != "837" do
          ValidationResult.add_issue(
            result,
            :error,
            "ST",
            idx,
            1,
            "Expected transaction set '837' but found '#{transaction_id}'"
          )
        else
          result
        end

        {new_result, %{new_state | st_control: control}}

      "SE" ->
        se_control = Enum.at(segment, 2)
        new_result = check_control_match(result, state.st_control, se_control, "SE", "ST", idx, 2)
        {new_result, state}

      _ ->
        {result, state}
    end
  end

  defp check_control_match(result, expected, actual, segment_id, match_segment, idx, element_pos) do
    if expected && actual && expected != actual do
      ValidationResult.add_issue(
        result,
        :error,
        segment_id,
        idx,
        element_pos,
        "#{segment_id} control number '#{actual}' does not match #{match_segment} '#{expected}'"
      )
    else
      result
    end
  end

  defp check_count_match(result, expected, actual, segment_id, item_type, idx, element_pos) do
    if expected && to_string(actual) != expected do
      ValidationResult.add_issue(
        result,
        :error,
        segment_id,
        idx,
        element_pos,
        "#{segment_id} reports #{expected} #{item_type} but found #{actual}"
      )
    else
      result
    end
  end

  defp check_required_envelope(result, count, segment_id) when count == 0 do
    ValidationResult.add_issue(result, :error, segment_id, 0, nil, "Missing #{segment_id} segment (required)")
  end

  defp check_required_envelope(result, _count, _segment_id), do: result

  # Validate individual segment content
  defp validate_segments(result, segments, delimiters) do
    segments
    |> Enum.with_index(1)
    |> Enum.reduce(result, fn {segment, idx}, acc ->
      segment_id = List.first(segment) || ""

      case segment_id do
        "NM1" -> validate_nm1(acc, segment, idx)
        "CLM" -> validate_clm(acc, segment, idx)
        "DTP" -> validate_dtp(acc, segment, idx)
        "HI" -> validate_hi(acc, segment, idx, delimiters)
        "SV1" -> validate_sv1(acc, segment, idx)
        _ -> acc
      end
    end)
  end

  defp validate_nm1(result, segment, idx) when length(segment) < 4 do
    ValidationResult.add_issue(
      result,
      :error,
      "NM1",
      idx,
      nil,
      "NM1 segment has insufficient elements (found #{length(segment)}, need at least 4)"
    )
  end

  defp validate_nm1(result, segment, idx) do
    entity_code = Enum.at(segment, 1, "")
    entity_type = Enum.at(segment, 2, "")
    entity_name = Enum.at(segment, 3, "")

    result
    |> check_entity_code(entity_code, idx)
    |> check_entity_type(entity_type, idx)
    |> check_entity_name(entity_name, idx)
  end

  defp check_entity_code(result, entity_code, idx) when entity_code != "" do
    if Map.has_key?(@entity_id_codes, entity_code) do
      result
    else
      ValidationResult.add_issue(
        result,
        :warning,
        "NM1",
        idx,
        1,
        "Entity identifier code '#{entity_code}' not recognized",
        "Valid codes: #{Enum.take(Map.keys(@entity_id_codes), 5) |> Enum.join(", ")}..."
      )
    end
  end

  defp check_entity_code(result, _entity_code, _idx), do: result

  defp check_entity_type(result, entity_type, idx) do
    if Map.has_key?(@entity_type_codes, entity_type) do
      result
    else
      ValidationResult.add_issue(
        result,
        :error,
        "NM1",
        idx,
        2,
        "Invalid entity type qualifier '#{entity_type}' (must be 1 or 2)"
      )
    end
  end

  defp check_entity_name(result, entity_name, idx) when entity_name == "" or is_nil(entity_name) do
    ValidationResult.add_issue(result, :error, "NM1", idx, 3, "Entity name is required but empty")
  end

  defp check_entity_name(result, _entity_name, _idx), do: result

  defp validate_clm(result, segment, idx) when length(segment) < 6 do
    ValidationResult.add_issue(
      result,
      :error,
      "CLM",
      idx,
      nil,
      "CLM segment has insufficient elements (found #{length(segment)}, need at least 6)"
    )
  end

  defp validate_clm(result, segment, idx) do
    claim_amount = Enum.at(segment, 2, "")

    case Float.parse(claim_amount) do
      {amount, _} when amount <= 0 ->
        ValidationResult.add_issue(
          result,
          :warning,
          "CLM",
          idx,
          2,
          "Claim amount is #{amount} (should be positive)"
        )

      {_amount, _} ->
        result

      :error ->
        ValidationResult.add_issue(
          result,
          :error,
          "CLM",
          idx,
          2,
          "Claim amount '#{claim_amount}' is not a valid number"
        )
    end
  end

  defp validate_dtp(result, segment, idx) when length(segment) < 4 do
    ValidationResult.add_issue(
      result,
      :error,
      "DTP",
      idx,
      nil,
      "DTP segment has insufficient elements (found #{length(segment)}, need 4)"
    )
  end

  defp validate_dtp(result, segment, idx) do
    date_format = Enum.at(segment, 2, "")
    date_value = Enum.at(segment, 3, "")

    result
    |> check_date_format(date_format, idx)
    |> check_date_value(date_value, date_format, idx)
  end

  defp check_date_format(result, date_format, idx) when date_format not in ["D8", "RD8"] do
    ValidationResult.add_issue(
      result,
      :warning,
      "DTP",
      idx,
      2,
      "Date format qualifier '#{date_format}' not standard (expected D8 or RD8)"
    )
  end

  defp check_date_format(result, _date_format, _idx), do: result

  defp check_date_value(result, date_value, "D8", idx) do
    if Regex.match?(~r/^\d{8}$/, date_value) do
      year = String.slice(date_value, 0, 4) |> String.to_integer()
      month = String.slice(date_value, 4, 2) |> String.to_integer()
      day = String.slice(date_value, 6, 2) |> String.to_integer()

      result
      |> check_year(year, idx)
      |> check_month(month, idx)
      |> check_day(day, idx)
    else
      ValidationResult.add_issue(
        result,
        :error,
        "DTP",
        idx,
        3,
        "Date '#{date_value}' not in CCYYMMDD format"
      )
    end
  end

  defp check_date_value(result, _date_value, _format, _idx), do: result

  defp check_year(result, year, idx) when year < @min_valid_year or year > @max_valid_year do
    ValidationResult.add_issue(result, :warning, "DTP", idx, 3, "Date year #{year} seems unusual")
  end

  defp check_year(result, _year, _idx), do: result

  defp check_month(result, month, idx) when month < 1 or month > 12 do
    ValidationResult.add_issue(result, :error, "DTP", idx, 3, "Date month #{month} is invalid")
  end

  defp check_month(result, _month, _idx), do: result

  defp check_day(result, day, idx) when day < 1 or day > 31 do
    ValidationResult.add_issue(result, :error, "DTP", idx, 3, "Date day #{day} is invalid")
  end

  defp check_day(result, _day, _idx), do: result

  defp validate_hi(result, segment, idx, _delimiters) when length(segment) < 2 do
    ValidationResult.add_issue(
      result,
      :error,
      "HI",
      idx,
      nil,
      "HI segment must contain at least one diagnosis code"
    )
  end

  defp validate_hi(result, segment, idx, %{sub_element: sub_elem_sep}) do
    segment
    |> Enum.drop(1)
    |> Enum.with_index(1)
    |> Enum.reduce(result, fn {element, pos}, acc ->
      if String.contains?(element, sub_elem_sep) do
        [qualifier | rest] = String.split(element, sub_elem_sep)
        code = Enum.join(rest, sub_elem_sep)

        acc
        |> check_diagnosis_qualifier(qualifier, idx, pos)
        |> check_diagnosis_code(code, idx, pos)
      else
        acc
      end
    end)
  end

  defp check_diagnosis_qualifier(result, qualifier, idx, pos) when qualifier not in ["ABK", "BK"] do
    ValidationResult.add_issue(
      result,
      :warning,
      "HI",
      idx,
      pos,
      "Diagnosis code qualifier '#{qualifier}' not standard"
    )
  end

  defp check_diagnosis_qualifier(result, _qualifier, _idx, _pos), do: result

  defp check_diagnosis_code(result, code, idx, pos) when code == "" or is_nil(code) do
    ValidationResult.add_issue(result, :error, "HI", idx, pos, "Diagnosis code is empty")
  end

  defp check_diagnosis_code(result, _code, _idx, _pos), do: result

  defp validate_sv1(result, segment, idx) when length(segment) < 3 do
    ValidationResult.add_issue(
      result,
      :error,
      "SV1",
      idx,
      nil,
      "SV1 segment has insufficient elements (found #{length(segment)})"
    )
  end

  defp validate_sv1(result, segment, idx) do
    line_charge = Enum.at(segment, 2, "")
    units = Enum.at(segment, 4, "")

    result
    |> check_line_charge(line_charge, idx)
    |> check_units(units, idx)
  end

  defp check_line_charge(result, line_charge, idx) do
    case Float.parse(line_charge) do
      {amount, _} when amount < 0 ->
        ValidationResult.add_issue(
          result,
          :warning,
          "SV1",
          idx,
          2,
          "Line item charge is negative: #{amount}"
        )

      {_amount, _} ->
        result

      :error ->
        ValidationResult.add_issue(
          result,
          :error,
          "SV1",
          idx,
          2,
          "Line item charge '#{line_charge}' is not a valid number"
        )
    end
  end

  defp check_units(result, "", _idx), do: result
  defp check_units(result, nil, _idx), do: result

  defp check_units(result, units, idx) do
    case Float.parse(units) do
      {count, _} when count <= 0 ->
        ValidationResult.add_issue(
          result,
          :warning,
          "SV1",
          idx,
          4,
          "Service units should be positive (found #{count})"
        )

      {_count, _} ->
        result

      :error ->
        ValidationResult.add_issue(
          result,
          :error,
          "SV1",
          idx,
          4,
          "Service units '#{units}' is not a valid number"
        )
    end
  end

  # Validate business logic and relationships
  defp validate_business_rules(result, segments, _delimiters) do
    business_state = %{
      has_billing_provider: false,
      has_subscriber: false,
      has_patient: false,
      has_claim: false,
      claim_amount: 0.0,
      service_line_total: 0.0
    }

    final_state = 
      segments
      |> Enum.reduce(business_state, fn segment, state ->
        segment_id = List.first(segment) || ""
        update_business_state(state, segment, segment_id)
      end)

    result
    |> check_required_entity(final_state.has_billing_provider, "Billing Provider (NM1*85)")
    |> check_required_entity(final_state.has_subscriber, "Subscriber/Insured (NM1*IL)")
    |> check_required_entity(final_state.has_claim, "CLM (Claim Information) segment", "CLM")
    |> check_claim_total(final_state.claim_amount, final_state.service_line_total)
  end

  defp update_business_state(state, segment, "NM1") do
    entity_code = Enum.at(segment, 1, "")

    case entity_code do
      "85" -> %{state | has_billing_provider: true}
      "IL" -> %{state | has_subscriber: true}
      "QC" -> %{state | has_patient: true}
      _ -> state
    end
  end

  defp update_business_state(state, segment, "CLM") do
    claim_amount = 
      case Float.parse(Enum.at(segment, 2, "0")) do
        {amount, _} -> amount
        :error -> 0.0
      end

    %{state | has_claim: true, claim_amount: claim_amount}
  end

  defp update_business_state(state, segment, "SV1") do
    line_charge = 
      case Float.parse(Enum.at(segment, 2, "0")) do
        {amount, _} -> amount
        :error -> 0.0
      end

    %{state | service_line_total: state.service_line_total + line_charge}
  end

  defp update_business_state(state, _segment, _segment_id), do: state

  defp check_required_entity(result, has_entity, entity_name, segment_id \\ "NM1")
  
  defp check_required_entity(result, false, entity_name, segment_id) do
    ValidationResult.add_issue(
      result,
      :error,
      segment_id,
      0,
      nil,
      "Missing required #{entity_name}"
    )
  end

  defp check_required_entity(result, true, _entity_name, _segment_id), do: result

  defp check_claim_total(result, claim_amount, service_line_total)
      when claim_amount > 0 and service_line_total > 0 do
    difference = abs(claim_amount - service_line_total)

    if difference > @rounding_tolerance do
      ValidationResult.add_issue(
        result,
        :warning,
        "CLM",
        0,
        2,
        "Claim amount ($#{format_currency(claim_amount)}) " <>
        "does not match service line total ($#{format_currency(service_line_total)})"
      )
    else
      result
    end
  end

  defp check_claim_total(result, _claim_amount, _service_line_total), do: result

  # Helper function to format currency
  defp format_currency(amount) when is_float(amount) do
    :erlang.float_to_binary(amount, decimals: 2)
  end

  defp format_currency(amount), do: to_string(amount)
end

defmodule X12.Validator.CLI do
  @moduledoc "Command-line interface for X12 validator"

  alias X12.Validator
  alias X12.Validator.ValidationResult

  def main(args) do
    case args do
      [filepath] ->
        IO.puts("Validating X12 file: #{filepath}\n")
        result = Validator.validate_file(filepath)
        print_report(result)
        exit_code(result)

      _ ->
        print_usage()
        System.halt(1)
    end
  end

  defp print_usage do
    IO.puts("""
    Usage: elixir x12_validator.exs <path_to_x12_file>

    Example:
      elixir x12_validator.exs sample_837p_claim.x12
    """)
  end

  defp print_report(result) do
    IO.puts(String.duplicate("=", 80))
    IO.puts("X12 837P VALIDATION REPORT")
    IO.puts(String.duplicate("=", 80))

    IO.puts("\nTotal Segments Processed: #{result.segment_count}")
    IO.puts("Overall Status: #{if result.valid?, do: "✓ VALID", else: "✗ INVALID"}")

    summary = ValidationResult.get_summary(result)
    IO.puts("\nIssue Summary:")
    IO.puts("  Errors:   #{summary.error}")
    IO.puts("  Warnings: #{summary.warning}")
    IO.puts("  Info:     #{summary.info}")

    if length(result.issues) > 0 do
      IO.puts("\n" <> String.duplicate("-", 80))
      IO.puts("VALIDATION ISSUES")
      IO.puts(String.duplicate("-", 80))

      # Print by level
      for level <- [:error, :warning, :info] do
        level_issues = Enum.filter(result.issues, &(&1.level == level))

        if length(level_issues) > 0 do
          IO.puts("\n#{String.upcase(to_string(level))}S (#{length(level_issues)}):")
          IO.puts(String.duplicate("-", 80))

          level_issues
          |> Enum.reverse()
          |> Enum.each(&print_issue/1)
        end
      end
    else
      IO.puts("\n✓ No validation issues found!")
    end

    IO.puts("\n" <> String.duplicate("=", 80) <> "\n")
  end

  defp print_issue(issue) do
    element_info = if issue.element_position do
      ", Element #{issue.element_position}"
    else
      ""
    end

    IO.puts("  [#{issue.segment_id}] Segment #{issue.segment_number}#{element_info}")
    IO.puts("    #{issue.message}")

    if issue.context != "" do
      IO.puts("    Context: #{issue.context}")
    end

    IO.puts("")
  end

  defp exit_code(%{valid?: true}), do: System.halt(0)
  defp exit_code(%{valid?: false}), do: System.halt(1)
end

# Run the CLI
X12.Validator.CLI.main(System.argv())

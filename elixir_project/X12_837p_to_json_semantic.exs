#!/usr/bin/env elixir

defmodule X12Parser do
  @moduledoc """
  Parser for X12 EDI format files
  """

  defstruct content: "",
            segment_terminator: "~",
            element_separator: "*",
            subelement_separator: ":",
            segments: []

  def new(content) do
    %X12Parser{content: content}
  end

  def parse(%X12Parser{} = parser) do
    # Remove newlines and split by segment terminator
    clean_content =
      parser.content
      |> String.replace("\n", "")
      |> String.replace("\r", "")

    segments =
      clean_content
      |> String.trim()
      |> String.split(parser.segment_terminator)
      |> Enum.filter(&(String.trim(&1) != ""))
      |> Enum.map(&String.split(&1, parser.element_separator))

    %{parser | segments: segments}
  end

  def get_segment(%X12Parser{segments: segments}, segment_id) do
    Enum.find(segments, fn [id | _] -> id == segment_id end)
  end

  def get_all_segments(%X12Parser{segments: segments}, segment_id) do
    Enum.filter(segments, fn [id | _] -> id == segment_id end)
  end

  def find_segment_index(%X12Parser{segments: segments}, segment_id, start_index \\ 0) do
    segments
    |> Enum.drop(start_index)
    |> Enum.find_index(fn [id | _] -> id == segment_id end)
    |> case do
      nil -> -1
      index -> start_index + index
    end
  end
end

defmodule X12_837P_Converter do
  @moduledoc """
  Converts X12 837P claims to semantic JSON
  """

  def convert(parser) do
    %{
      metadata: parse_metadata(parser),
      interchange: parse_isa(parser),
      functionalGroup: parse_gs(parser),
      transactionSet: parse_st(parser),
      beginningOfHierarchicalTransaction: parse_bht(parser),
      submitter: parse_submitter(parser),
      receiver: parse_receiver(parser),
      providers: parse_providers(parser),
      subscribers: parse_subscribers(parser),
      claims: parse_claims(parser),
      controlTotals: parse_control_totals(parser)
    }
  end

  # Metadata
  defp parse_metadata(parser) do
    st_segment = X12Parser.get_segment(parser, "ST")

    %{
      transactionSet: get_element(st_segment, 1),
      transactionType: "Professional Claim",
      version: get_element(st_segment, 3),
      conversionTimestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      sourceFile: "X12 EDI Stream"
    }
  end

  # ISA - Interchange Control Header
  defp parse_isa(parser) do
    isa = X12Parser.get_segment(parser, "ISA")

    %{
      senderId: get_element(isa, 6) |> String.trim(),
      senderQualifier: get_element(isa, 5) |> String.trim(),
      receiverId: get_element(isa, 8) |> String.trim(),
      receiverQualifier: get_element(isa, 7) |> String.trim(),
      date: format_date(get_element(isa, 9)),
      time: format_time(get_element(isa, 10)),
      controlNumber: get_element(isa, 13) |> String.trim(),
      versionNumber: get_element(isa, 12) |> String.trim(),
      testIndicator: get_element(isa, 15) |> String.trim()
    }
  end

  # GS - Functional Group Header
  defp parse_gs(parser) do
    gs = X12Parser.get_segment(parser, "GS")

    %{
      functionalCode: get_element(gs, 1),
      applicationSender: get_element(gs, 2),
      applicationReceiver: get_element(gs, 3),
      date: format_date(get_element(gs, 4)),
      time: format_time(get_element(gs, 5)),
      controlNumber: get_element(gs, 6),
      responsibleAgency: get_element(gs, 7),
      version: get_element(gs, 8)
    }
  end

  # ST - Transaction Set Header
  defp parse_st(parser) do
    st = X12Parser.get_segment(parser, "ST")

    %{
      controlNumber: get_element(st, 2),
      implementationGuide: get_element(st, 3)
    }
  end

  # BHT - Beginning of Hierarchical Transaction
  defp parse_bht(parser) do
    bht = X12Parser.get_segment(parser, "BHT")

    %{
      structureCode: get_element(bht, 1),
      purposeCode: get_element(bht, 2),
      referenceId: get_element(bht, 3),
      date: format_date(get_element(bht, 4)),
      time: format_time(get_element(bht, 5)),
      transactionTypeCode: get_element(bht, 6)
    }
  end

  # Submitter (NM1*41)
  defp parse_submitter(parser) do
    nm1 =
      parser.segments
      |> Enum.find(fn
        ["NM1", "41" | _] -> true
        _ -> false
      end)

    case nm1 do
      nil ->
        %{}

      _ ->
        nm1_index = Enum.find_index(parser.segments, &(&1 == nm1))

        per =
          parser.segments
          |> Enum.drop(nm1_index)
          |> Enum.take(5)
          |> Enum.find(fn
            ["PER" | _] -> true
            _ -> false
          end)

        submitter = %{
          organizationName: get_element(nm1, 3),
          identifierCode: get_element(nm1, 9),
          identifierQualifier: get_element(nm1, 8)
        }

        case per do
          nil ->
            submitter

          _ ->
            Map.put(submitter, :contact, %{
              name: get_element(per, 2),
              phone: get_element(per, 4),
              extension: get_element(per, 6)
            })
        end
    end
  end

  # Receiver (NM1*40)
  defp parse_receiver(parser) do
    nm1 =
      parser.segments
      |> Enum.find(fn
        ["NM1", "40" | _] -> true
        _ -> false
      end)

    case nm1 do
      nil ->
        %{}

      _ ->
        %{
          organizationName: get_element(nm1, 3),
          identifierCode: get_element(nm1, 9),
          identifierQualifier: get_element(nm1, 8)
        }
    end
  end

  # Providers (HL*20 loop)
  defp parse_providers(parser) do
    parser.segments
    |> Enum.with_index()
    |> Enum.filter(fn
      {["HL", _, _, "20" | _], _} -> true
      _ -> false
    end)
    |> Enum.map(fn {hl_segment, index} ->
      provider = %{
        hierarchicalLevel: get_element(hl_segment, 1),
        levelCode: get_element(hl_segment, 3),
        hasChildren: get_element(hl_segment, 4) == "1",
        providerType: "billing"
      }

      # Get segments after this HL until next HL
      loop_segments =
        parser.segments
        |> Enum.drop(index + 1)
        |> Enum.take_while(fn
          ["HL" | _] -> false
          _ -> true
        end)

      parse_provider_loop(provider, loop_segments)
    end)
  end

  defp parse_provider_loop(provider, segments) do
    Enum.reduce(segments, provider, fn segment, acc ->
      case segment do
        ["NM1", "85" | rest] ->
          Map.put(acc, :organization, %{
            name: get_element(segment, 3),
            npi: get_element(segment, 9)
          })

        ["N3" | _] ->
          address = Map.get(acc, :address, %{})
          Map.put(acc, :address, Map.put(address, :street, get_element(segment, 1)))

        ["N4" | _] ->
          address = Map.get(acc, :address, %{})

          address =
            address
            |> Map.put(:city, get_element(segment, 1))
            |> Map.put(:state, get_element(segment, 2))
            |> Map.put(:zip, get_element(segment, 3))

          Map.put(acc, :address, address)

        ["REF", "EI" | _] ->
          org = Map.get(acc, :organization, %{})
          Map.put(acc, :organization, Map.put(org, :taxId, get_element(segment, 2)))

        _ ->
          acc
      end
    end)
  end

  # Subscribers (HL*22 loop)
  defp parse_subscribers(parser) do
    parser.segments
    |> Enum.with_index()
    |> Enum.filter(fn
      {["HL", _, _, "22" | _], _} -> true
      _ -> false
    end)
    |> Enum.map(fn {hl_segment, index} ->
      subscriber = %{
        hierarchicalLevel: get_element(hl_segment, 1),
        parentLevel: get_element(hl_segment, 2),
        levelCode: get_element(hl_segment, 3),
        hasChildren: get_element(hl_segment, 4) == "1"
      }

      # Get segments after this HL until next HL or CLM
      loop_segments =
        parser.segments
        |> Enum.drop(index + 1)
        |> Enum.take_while(fn
          ["HL" | _] -> false
          ["CLM" | _] -> false
          _ -> true
        end)

      parse_subscriber_loop(subscriber, loop_segments)
    end)
  end

  defp parse_subscriber_loop(subscriber, segments) do
    Enum.reduce(segments, subscriber, fn segment, acc ->
      case segment do
        ["SBR" | _] ->
          acc
          |> Map.put(:payerResponsibility, decode_payer_responsibility(get_element(segment, 1)))
          |> Map.put(:relationshipCode, get_element(segment, 2))
          |> Map.put(:claimFilingIndicator, get_element(segment, 9))

        ["NM1", "IL" | _] ->
          patient = Map.get(acc, :patient, %{})

          patient =
            patient
            |> Map.put(:lastName, get_element(segment, 3))
            |> Map.put(:firstName, get_element(segment, 4))
            |> Map.put(:middleName, get_element(segment, 5))
            |> Map.put(:memberId, get_element(segment, 9))

          Map.put(acc, :patient, patient)

        ["NM1", "PR" | _] ->
          Map.put(acc, :payer, %{
            name: get_element(segment, 3),
            payerId: get_element(segment, 9),
            identifierQualifier: get_element(segment, 8)
          })

        ["N3" | _] ->
          patient = Map.get(acc, :patient, %{})
          address = Map.get(patient, :address, %{})
          address = Map.put(address, :street, get_element(segment, 1))
          Map.put(acc, :patient, Map.put(patient, :address, address))

        ["N4" | _] ->
          patient = Map.get(acc, :patient, %{})
          address = Map.get(patient, :address, %{})

          address =
            address
            |> Map.put(:city, get_element(segment, 1))
            |> Map.put(:state, get_element(segment, 2))
            |> Map.put(:zip, get_element(segment, 3))

          Map.put(acc, :patient, Map.put(patient, :address, address))

        ["DMG" | _] ->
          patient = Map.get(acc, :patient, %{})
          demographics = Map.get(patient, :demographics, %{})

          demographics =
            demographics
            |> Map.put(:dateOfBirth, format_date(get_element(segment, 2)))
            |> Map.put(:gender, get_element(segment, 3))

          Map.put(acc, :patient, Map.put(patient, :demographics, demographics))

        _ ->
          acc
      end
    end)
  end

  # Claims (CLM segment and service lines)
  defp parse_claims(parser) do
    parser.segments
    |> Enum.with_index()
    |> Enum.filter(fn
      {["CLM" | _], _} -> true
      _ -> false
    end)
    |> Enum.map(fn {clm_segment, index} ->
      claim_info = get_element(clm_segment, 5) |> String.split(":")

      claim = %{
        claimId: get_element(clm_segment, 1),
        totalChargeAmount: parse_float(get_element(clm_segment, 2)),
        placeOfService: Enum.at(claim_info, 0),
        claimFrequency: Enum.at(claim_info, 2),
        providerSignature: get_element(clm_segment, 6),
        assignmentOfBenefits: get_element(clm_segment, 7),
        releaseOfInformation: get_element(clm_segment, 8),
        patientSignature: get_element(clm_segment, 9)
      }

      # Get segments after this CLM until next CLM or SE
      loop_segments =
        parser.segments
        |> Enum.drop(index + 1)
        |> Enum.take_while(fn
          ["CLM" | _] -> false
          ["SE" | _] -> false
          _ -> true
        end)

      claim = parse_claim_loop(claim, loop_segments)
      service_lines = parse_service_lines(loop_segments)
      Map.put(claim, :serviceLines, service_lines)
    end)
  end

  defp parse_claim_loop(claim, segments) do
    Enum.reduce(segments, claim, fn segment, acc ->
      case segment do
        ["DTP", "431" | _] ->
          dates = Map.get(acc, :dates, %{})

          Map.put(
            acc,
            :dates,
            Map.put(dates, :admissionDate, format_date(get_element(segment, 3)))
          )

        ["DTP", "434" | _] ->
          date_range = get_element(segment, 3) |> String.split("-")
          dates = Map.get(acc, :dates, %{})

          dates =
            if length(date_range) == 2 do
              dates
              |> Map.put(:admissionDate, format_date(Enum.at(date_range, 0)))
              |> Map.put(:dischargeDate, format_date(Enum.at(date_range, 1)))
            else
              dates
            end

          Map.put(acc, :dates, dates)

        ["CL1" | _] ->
          acc
          |> Map.put(:admissionType, get_element(segment, 1))
          |> Map.put(:admissionSource, get_element(segment, 2))
          |> Map.put(:patientStatus, get_element(segment, 3))

        ["HI" | rest] ->
          diagnoses = Map.get(acc, :diagnoses, %{additional: []})

          # Parse all diagnosis codes in this HI segment
          diagnoses =
            rest
            |> Enum.reduce(diagnoses, fn diag_str, diag_acc ->
              case String.split(diag_str, ":") do
                [code_type, code] ->
                  diag = %{code: code, codeType: code_type}

                  if Map.has_key?(diag_acc, :principal) do
                    Map.update!(diag_acc, :additional, &(&1 ++ [diag]))
                  else
                    Map.put(diag_acc, :principal, diag)
                  end

                _ ->
                  diag_acc
              end
            end)

          Map.put(acc, :diagnoses, diagnoses)

        _ ->
          acc
      end
    end)
  end

  # Service Lines (LX/SV1 segments)
  defp parse_service_lines(segments) do
    segments
    |> Enum.with_index()
    |> Enum.filter(fn
      {["LX" | _], _} -> true
      _ -> false
    end)
    |> Enum.map(fn {lx_segment, index} ->
      service_line = %{
        lineNumber: parse_int(get_element(lx_segment, 1))
      }

      # Get segments after this LX until next LX
      line_segments =
        segments
        |> Enum.drop(index + 1)
        |> Enum.take_while(fn
          ["LX" | _] -> false
          _ -> true
        end)

      parse_service_line_loop(service_line, line_segments)
    end)
  end

  defp parse_service_line_loop(service_line, segments) do
    Enum.reduce(segments, service_line, fn segment, acc ->
      case segment do
        ["SV1" | _] ->
          proc_parts = get_element(segment, 1) |> String.split(":")
          code = Enum.at(proc_parts, 1)

          procedure = %{
            code: code,
            codeType: Enum.at(proc_parts, 0),
            description: get_procedure_description(code)
          }

          acc
          |> Map.put(:procedure, procedure)
          |> Map.put(:chargeAmount, parse_float(get_element(segment, 2)))
          |> Map.put(:unit, get_element(segment, 3))
          |> Map.put(:quantity, parse_float(get_element(segment, 4)))
          |> Map.put(:placeOfService, get_element(segment, 6))

        ["DTP", "472" | _] ->
          Map.put(acc, :serviceDate, format_date(get_element(segment, 3)))

        _ ->
          acc
      end
    end)
  end

  # Control Totals
  defp parse_control_totals(parser) do
    se = X12Parser.get_segment(parser, "SE")
    ge = X12Parser.get_segment(parser, "GE")
    iea = X12Parser.get_segment(parser, "IEA")

    %{
      transactionSegmentCount: parse_int(get_element(se, 1)),
      functionalGroupCount: parse_int(get_element(ge, 1)),
      interchangeControlNumber: get_element(iea, 2)
    }
  end

  # Helper functions

  defp get_element(nil, _), do: nil

  defp get_element(list, index) when is_list(list) do
    Enum.at(list, index)
  end

  defp format_date(nil), do: nil
  defp format_date(""), do: nil

  defp format_date(date_str) when is_binary(date_str) and byte_size(date_str) >= 8 do
    year = String.slice(date_str, 0, 4)
    month = String.slice(date_str, 4, 2)
    day = String.slice(date_str, 6, 2)
    "#{year}-#{month}-#{day}"
  end

  defp format_date(_), do: nil

  defp format_time(nil), do: nil
  defp format_time(""), do: nil

  defp format_time(time_str) when is_binary(time_str) and byte_size(time_str) >= 4 do
    hour = String.slice(time_str, 0, 2)
    minute = String.slice(time_str, 2, 2)
    "#{hour}:#{minute}"
  end

  defp format_time(_), do: nil

  defp parse_float(nil), do: nil
  defp parse_float(""), do: nil

  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {float, _} -> float
      :error -> nil
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp decode_payer_responsibility("P"), do: "Primary"
  defp decode_payer_responsibility("S"), do: "Secondary"
  defp decode_payer_responsibility("T"), do: "Tertiary"
  defp decode_payer_responsibility(code), do: code

  defp get_procedure_description("99213"), do: "Office/outpatient visit, established patient"
  defp get_procedure_description("80053"), do: "Comprehensive metabolic panel"
  defp get_procedure_description("85025"), do: "Complete blood count"
  defp get_procedure_description(_), do: ""
end

defmodule X12ToJSON do
  @moduledoc """
  Main module for X12 to JSON conversion
  """

  def main(args) do
    case args do
      [] ->
        IO.puts("Usage: elixir x12_to_json_converter.exs <input_file.x12> [output_file.json]")
        IO.puts("\nExample:")
        IO.puts("  elixir x12_to_json_converter.exs sample_837p_claim.x12")
        IO.puts("  elixir x12_to_json_converter.exs sample_837p_claim.x12 output.json")
        System.halt(1)

      [input_file] ->
        convert_and_print(input_file)

      [input_file, output_file] ->
        convert_and_save(input_file, output_file)

      _ ->
        IO.puts("Error: Too many arguments")
        System.halt(1)
    end
  end

  defp convert_and_print(input_file) do
    case read_and_convert(input_file) do
      {:ok, json} ->
        IO.puts(json)

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end

  defp convert_and_save(input_file, output_file) do
    case read_and_convert(input_file) do
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

  defp read_and_convert(input_file) do
    case File.read(input_file) do
      {:ok, content} ->
        parser = X12Parser.new(content) |> X12Parser.parse()
        result = X12_837P_Converter.convert(parser)
        json = Jason.encode!(result, pretty: true)
        {:ok, json}

      {:error, :enoent} ->
        {:error, "File '#{input_file}' not found"}

      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
    end
  end
end

# Run the main function
X12ToJSON.main(System.argv())

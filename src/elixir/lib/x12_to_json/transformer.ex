defmodule X12ToJson.Transformer do
  @moduledoc """
  Transforms parsed X12 data into semantic JSON structure
  """

  alias X12ToJson.Parser
  alias X12ToJson.Helpers

  # Constants for segment loop sizes
  @max_related_segments 5
  @max_provider_segments 20
  @max_subscriber_segments 30
  @max_claim_segments 50

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
    st_segment = Parser.get_segment(parser, "ST")

    %{
      transactionSet: Helpers.get_element(st_segment, 1),
      transactionType: "Professional Claim",
      version: Helpers.get_element(st_segment, 3),
      conversionTimestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      sourceFile: "X12 EDI Stream"
    }
  end

  # ISA - Interchange Control Header
  defp parse_isa(parser) do
    isa = Parser.get_segment(parser, "ISA")

    %{
      senderId: safe_trim(Helpers.get_element(isa, 6)),
      senderQualifier: safe_trim(Helpers.get_element(isa, 5)),
      receiverId: safe_trim(Helpers.get_element(isa, 8)),
      receiverQualifier: safe_trim(Helpers.get_element(isa, 7)),
      date: Helpers.format_date(Helpers.get_element(isa, 9)),
      time: Helpers.format_time(Helpers.get_element(isa, 10)),
      controlNumber: safe_trim(Helpers.get_element(isa, 13)),
      versionNumber: safe_trim(Helpers.get_element(isa, 12)),
      testIndicator: safe_trim(Helpers.get_element(isa, 15))
    }
  end

  # Helper to safely trim strings, handling nil values
  defp safe_trim(nil), do: nil
  defp safe_trim(value) when is_binary(value), do: String.trim(value)
  defp safe_trim(value), do: value

  # GS - Functional Group Header
  defp parse_gs(parser) do
    gs = Parser.get_segment(parser, "GS")

    %{
      functionalCode: Helpers.get_element(gs, 1),
      applicationSender: Helpers.get_element(gs, 2),
      applicationReceiver: Helpers.get_element(gs, 3),
      date: Helpers.format_date(Helpers.get_element(gs, 4)),
      time: Helpers.format_time(Helpers.get_element(gs, 5)),
      controlNumber: Helpers.get_element(gs, 6),
      responsibleAgency: Helpers.get_element(gs, 7),
      version: Helpers.get_element(gs, 8)
    }
  end

  # ST - Transaction Set Header
  defp parse_st(parser) do
    st = Parser.get_segment(parser, "ST")

    %{
      controlNumber: Helpers.get_element(st, 2),
      implementationGuide: Helpers.get_element(st, 3)
    }
  end

  # BHT - Beginning of Hierarchical Transaction
  defp parse_bht(parser) do
    bht = Parser.get_segment(parser, "BHT")

    %{
      structureCode: Helpers.get_element(bht, 1),
      purposeCode: Helpers.get_element(bht, 2),
      referenceId: Helpers.get_element(bht, 3),
      date: Helpers.format_date(Helpers.get_element(bht, 4)),
      time: Helpers.format_time(Helpers.get_element(bht, 5)),
      transactionTypeCode: Helpers.get_element(bht, 6)
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
          organizationName: Helpers.get_element(nm1, 3),
          identifierCode: Helpers.get_element(nm1, 9),
          identifierQualifier: Helpers.get_element(nm1, 8)
        }

        case per do
          nil ->
            submitter

          _ ->
            Map.put(submitter, :contact, %{
              name: Helpers.get_element(per, 2),
              phone: Helpers.get_element(per, 4),
              extension: Helpers.get_element(per, 6)
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
          organizationName: Helpers.get_element(nm1, 3),
          identifierCode: Helpers.get_element(nm1, 9),
          identifierQualifier: Helpers.get_element(nm1, 8)
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
        hierarchicalLevel: Helpers.get_element(hl_segment, 1),
        levelCode: Helpers.get_element(hl_segment, 3),
        hasChildren: Helpers.get_element(hl_segment, 4) == "1",
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
        ["NM1", "85" | _] ->
          Map.put(acc, :organization, %{
            name: Helpers.get_element(segment, 3),
            npi: Helpers.get_element(segment, 9)
          })

        ["N3" | _] ->
          address = Map.get(acc, :address, %{})
          Map.put(acc, :address, Map.put(address, :street, Helpers.get_element(segment, 1)))

        ["N4" | _] ->
          address = Map.get(acc, :address, %{})

          address =
            address
            |> Map.put(:city, Helpers.get_element(segment, 1))
            |> Map.put(:state, Helpers.get_element(segment, 2))
            |> Map.put(:zip, Helpers.get_element(segment, 3))

          Map.put(acc, :address, address)

        ["REF", "EI" | _] ->
          org = Map.get(acc, :organization, %{})
          Map.put(acc, :organization, Map.put(org, :taxId, Helpers.get_element(segment, 2)))

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
        hierarchicalLevel: Helpers.get_element(hl_segment, 1),
        parentLevel: Helpers.get_element(hl_segment, 2),
        levelCode: Helpers.get_element(hl_segment, 3),
        hasChildren: Helpers.get_element(hl_segment, 4) == "1"
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
          |> Map.put(:payerResponsibility, Helpers.decode_payer_responsibility(Helpers.get_element(segment, 1)))
          |> Map.put(:relationshipCode, Helpers.get_element(segment, 2))
          |> Map.put(:claimFilingIndicator, Helpers.get_element(segment, 9))

        ["NM1", "IL" | _] ->
          patient = Map.get(acc, :patient, %{})

          patient =
            patient
            |> Map.put(:lastName, Helpers.get_element(segment, 3))
            |> Map.put(:firstName, Helpers.get_element(segment, 4))
            |> Map.put(:middleName, Helpers.get_element(segment, 5))
            |> Map.put(:memberId, Helpers.get_element(segment, 9))

          Map.put(acc, :patient, patient)

        ["NM1", "PR" | _] ->
          Map.put(acc, :payer, %{
            name: Helpers.get_element(segment, 3),
            payerId: Helpers.get_element(segment, 9),
            identifierQualifier: Helpers.get_element(segment, 8)
          })

        ["N3" | _] ->
          patient = Map.get(acc, :patient, %{})
          address = Map.get(patient, :address, %{})
          address = Map.put(address, :street, Helpers.get_element(segment, 1))
          Map.put(acc, :patient, Map.put(patient, :address, address))

        ["N4" | _] ->
          patient = Map.get(acc, :patient, %{})
          address = Map.get(patient, :address, %{})

          address =
            address
            |> Map.put(:city, Helpers.get_element(segment, 1))
            |> Map.put(:state, Helpers.get_element(segment, 2))
            |> Map.put(:zip, Helpers.get_element(segment, 3))

          Map.put(acc, :patient, Map.put(patient, :address, address))

        ["DMG" | _] ->
          patient = Map.get(acc, :patient, %{})
          demographics = Map.get(patient, :demographics, %{})

          demographics =
            demographics
            |> Map.put(:dateOfBirth, Helpers.format_date(Helpers.get_element(segment, 2)))
            |> Map.put(:gender, Helpers.get_element(segment, 3))

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
      claim_info = Helpers.get_element(clm_segment, 5) |> String.split(":")

      claim = %{
        claimId: Helpers.get_element(clm_segment, 1),
        totalChargeAmount: Helpers.parse_float(Helpers.get_element(clm_segment, 2)),
        placeOfService: Enum.at(claim_info, 0),
        claimFrequency: Enum.at(claim_info, 2),
        providerSignature: Helpers.get_element(clm_segment, 6),
        assignmentOfBenefits: Helpers.get_element(clm_segment, 7),
        releaseOfInformation: Helpers.get_element(clm_segment, 8),
        patientSignature: Helpers.get_element(clm_segment, 9)
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
          Map.put(acc, :dates, Map.put(dates, :admissionDate, Helpers.format_date(Helpers.get_element(segment, 3))))

        ["DTP", "434" | _] ->
          date_range = Helpers.get_element(segment, 3) |> String.split("-")
          dates = Map.get(acc, :dates, %{})

          dates =
            if length(date_range) == 2 do
              dates
              |> Map.put(:admissionDate, Helpers.format_date(Enum.at(date_range, 0)))
              |> Map.put(:dischargeDate, Helpers.format_date(Enum.at(date_range, 1)))
            else
              dates
            end

          Map.put(acc, :dates, dates)

        ["CL1" | _] ->
          acc
          |> Map.put(:admissionType, Helpers.get_element(segment, 1))
          |> Map.put(:admissionSource, Helpers.get_element(segment, 2))
          |> Map.put(:patientStatus, Helpers.get_element(segment, 3))

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
        lineNumber: Helpers.parse_int(Helpers.get_element(lx_segment, 1))
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
          proc_parts = Helpers.get_element(segment, 1) |> String.split(":")
          code = Enum.at(proc_parts, 1)

          procedure = %{
            code: code,
            codeType: Enum.at(proc_parts, 0),
            description: Helpers.get_procedure_description(code)
          }

          acc
          |> Map.put(:procedure, procedure)
          |> Map.put(:chargeAmount, Helpers.parse_float(Helpers.get_element(segment, 2)))
          |> Map.put(:unit, Helpers.get_element(segment, 3))
          |> Map.put(:quantity, Helpers.parse_float(Helpers.get_element(segment, 4)))
          |> Map.put(:placeOfService, Helpers.get_element(segment, 6))

        ["DTP", "472" | _] ->
          Map.put(acc, :serviceDate, Helpers.format_date(Helpers.get_element(segment, 3)))

        _ ->
          acc
      end
    end)
  end

  # Control Totals
  defp parse_control_totals(parser) do
    se = Parser.get_segment(parser, "SE")
    ge = Parser.get_segment(parser, "GE")
    iea = Parser.get_segment(parser, "IEA")

    %{
      transactionSegmentCount: Helpers.parse_int(Helpers.get_element(se, 1)),
      functionalGroupCount: Helpers.parse_int(Helpers.get_element(ge, 1)),
      interchangeControlNumber: Helpers.get_element(iea, 2)
    }
  end
end

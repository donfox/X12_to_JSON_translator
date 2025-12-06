# X12 to JSON Converter (Elixir)

Converts X12 EDI 837P (Professional Claims) format to semantic JSON.

## Installation

### Option 1: Standalone Script (No Dependencies)

Download the script and make it executable:

```bash
chmod +x X12_837P_to_JSON_semantic.exs
```

**Note:** This requires the `jason` hex package. Install it first:

```bash
mix archive.install hex jason
```

Run the script:

```bash
elixir X12_837P_to_JSON_semantic.exs input.x12 output.json
```

### Option 2: Mix Project (Recommended for Production)

1. Clone or download the project
2. Install dependencies:

```bash
mix deps.get
```

3. Build the executable:

```bash
mix escript.build
```

4. Run the converter:

```bash
./x12_to_json input.x12 output.json
```

## Usage

### Standalone Script

```bash
# Print to console
elixir X12_837P_to_JSON_semantic.exs sample_837p_claim.x12

# Save to file
elixir X12_837P_to_JSON_semantic.exs sample_837p_claim.x12 output.json
```

### Mix Project

```bash
# Print to console
./x12_to_json sample_837p_claim.x12

# Save to file
./x12_to_json sample_837p_claim.x12 output.json
```

## Project Structure

```
elixir_project/
├── mix.exs                          # Mix configuration
├── lib/
│   └── x12_to_json/
│       ├── cli.ex                   # Command-line interface
│       ├── converter.ex             # Main converter module
│       ├── parser.ex                # X12 parser
│       ├── transformer.ex           # X12 to JSON transformer
│       └── helpers.ex               # Helper functions
└── README.md
```

## Features

✅ **Semantic Mapping** - Human-readable field names  
✅ **Hierarchical Structure** - Preserves provider → subscriber → claim → service line relationships  
✅ **Data Type Conversion** - Dates formatted as YYYY-MM-DD, amounts as floats  
✅ **Code Translation** - Translates qualifiers like "P" → "Primary"  
✅ **Complete 837P Parsing** - Handles all major segments  
✅ **Concurrent Processing** - Leverages Elixir's concurrency model  

## Supported X12 Segments

- **ISA/IEA** - Interchange Control
- **GS/GE** - Functional Group
- **ST/SE** - Transaction Set
- **BHT** - Beginning of Hierarchical Transaction
- **NM1** - Name/Entity (Submitter, Receiver, Provider, Patient, Payer)
- **HL** - Hierarchical Level (Provider, Subscriber)
- **CLM** - Claim Information
- **LX/SV1** - Service Lines
- **HI** - Health Care Diagnosis Codes
- **DTP** - Date/Time Reference
- **N3/N4** - Address Information
- **REF** - Reference Information
- **PER** - Contact Information
- **DMG** - Demographics
- **SBR** - Subscriber Information

## Output Format

The converter produces semantic JSON with the following structure:

```json
{
  "metadata": { ... },
  "interchange": { ... },
  "functionalGroup": { ... },
  "transactionSet": { ... },
  "beginningOfHierarchicalTransaction": { ... },
  "submitter": { ... },
  "receiver": { ... },
  "providers": [ ... ],
  "subscribers": [ ... ],
  "claims": [
    {
      "claimId": "PATIENT001",
      "totalChargeAmount": 250.0,
      "serviceLines": [ ... ],
      "diagnoses": { ... }
    }
  ],
  "controlTotals": { ... }
}
```

## Development

### Running Tests

```bash
mix test
```

### Interactive Shell

```bash
iex -S mix

# Convert a file
{:ok, json} = X12ToJson.Converter.convert_file("sample_837p_claim.x12")
IO.puts(json)
```

### Formatting Code

```bash
mix format
```

## Integration with Phoenix

To integrate with a Phoenix application:

1. Add to your `mix.exs` dependencies:

```elixir
{:x12_to_json, path: "../x12_to_json"}
```

2. Use in your controllers:

```elixir
defmodule MyAppWeb.ClaimController do
  use MyAppWeb, :controller
  
  def convert(conn, %{"file" => file}) do
    case File.read(file.path) do
      {:ok, content} ->
        case X12ToJson.Converter.convert_content(content) do
          {:ok, json} ->
            json(conn, Jason.decode!(json))
          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: reason})
        end
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Could not read file"})
    end
  end
end
```

## Stream Processing for Large Files

For production use with large X12 files, consider using streams:

```elixir
defmodule X12ToJson.StreamProcessor do
  def process_large_file(input_path, output_path) do
    input_path
    |> File.stream!()
    |> Stream.map(&process_line/1)
    |> Stream.into(File.stream!(output_path))
    |> Stream.run()
  end
  
  defp process_line(line) do
    # Process each segment incrementally
  end
end
```

## Future Enhancements

- [ ] Support for 835 (Payment/Remittance)
- [ ] Support for 270/271 (Eligibility)
- [ ] Support for 276/277 (Claim Status)
- [ ] Schema validation
- [ ] Trading partner configuration
- [ ] Error recovery and partial parsing
- [ ] Performance benchmarks
- [ ] GenServer for concurrent processing

## Elixir Advantages

This Elixir implementation offers several advantages:

1. **Concurrency** - Process multiple X12 files simultaneously using Elixir's lightweight processes
2. **Fault Tolerance** - Supervisor trees for handling failures gracefully
3. **Stream Processing** - Handle large files efficiently without loading entire contents into memory
4. **Pattern Matching** - Clean, declarative segment parsing
5. **Hot Code Reloading** - Update converters without stopping the system
6. **Distribution** - Scale across multiple nodes for high-volume processing

## License

MIT

## Contributing

Contributions welcome! Please submit pull requests or open issues for bugs and feature requests.

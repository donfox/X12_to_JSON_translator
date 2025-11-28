defmodule X12ToJson.Parser do
  @moduledoc """
  Parser for X12 EDI format files
  """

  defstruct content: "",
            segment_terminator: "~",
            element_separator: "*",
            subelement_separator: ":",
            segments: []

  def new(content) do
    %__MODULE__{content: content}
  end

  def parse(%__MODULE__{} = parser) do
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

  def get_segment(%__MODULE__{segments: segments}, segment_id) do
    Enum.find(segments, fn
      [id | _] when id == segment_id -> true
      _ -> false
    end)
  end

  def get_all_segments(%__MODULE__{segments: segments}, segment_id) do
    Enum.filter(segments, fn
      [id | _] when id == segment_id -> true
      _ -> false
    end)
  end

  def find_segment_index(%__MODULE__{segments: segments}, segment_id, start_index \\ 0) do
    segments
    |> Enum.drop(start_index)
    |> Enum.find_index(fn
      [id | _] when id == segment_id -> true
      _ -> false
    end)
    |> case do
      nil -> -1
      index -> start_index + index
    end
  end
end

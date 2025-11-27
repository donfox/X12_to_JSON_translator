defmodule X12ToJson.MixProject do
  use Mix.Project

  def project do
    [
      app: :x12_to_json,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end

  defp escript do
    [main_module: X12ToJson.CLI]
  end
end

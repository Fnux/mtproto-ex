defmodule MTProto.Mixfile do
  use Mix.Project

  def project do
    [app: :mtproto,
     version: "0.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),

     # Docs
     name: "MTProto",
     source_url: "https://github.com/Fnux/mtproto-ex",
     homepage_url: "https://github.com/Fnux/mtproto-ex",
     docs: [main: "MTProto",
      extras: ["README.md"]]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:json, "~> 0.3.0"}, {:ex_doc, "~> 0.14", only: :dev}]
  end
end

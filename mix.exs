defmodule MTProto.Mixfile do
 use Mix.Project

  def project do
    [app: :telegram_mt,
     version: "0.0.1-alpha",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),

     # Docs
     name: "MTProto",
     source_url: "https://github.com/Fnux/telegram-mt-elixir",
     homepage_url: "https://github.com/Fnux/telegram-mt-elixir",
     docs: [main: "MTProto"]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :crypto],
     mod: {MTProto, []}]
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
    [{:ex_doc, "~> 0.14", only: :dev}, {:telegram_tl, github: "fnux/telegram-tl-elixir"}]
  end
end

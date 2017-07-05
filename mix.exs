defmodule MTProto.Mixfile do
 use Mix.Project

  def project do
    [app: :telegram_mt,
     version: "0.0.3-alpha",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps(),

     # Docs
     name: "Telegram MT",
     source_url: "https://github.com/Fnux/telegram-mt-elixir",
     homepage_url: "https://github.com/Fnux/telegram-mt-elixir",
     docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :crypto]]
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
    [{:ex_doc, "~> 0.14", only: :dev}, {:telegram_tl, "~> 0.1.0-beta"}]
  end

  defp description do
    """
    MTProto (Telegram) implementation for Elixir.
    """
  end

  defp package do
    [
      name: :telegram_mt,
      files: ["lib", "priv", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Timothée Floure"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Fnux/telegram-mt-elixir"}]
  end
end

defmodule LDNS.MixProject do
  use Mix.Project

  def project do
    [
      app: :ldns,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: compilers(Mix.env()),
      make_env: %{"MIX_ENV" => to_string(Mix.env())},
      make_clean: ["clean"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_make, "~> 0.9", runtime: false}
    ]
  end

  defp compilers(_) do
    [:elixir_make] ++ Mix.compilers()
  end
end

defmodule LDNS.MixProject do
  use Mix.Project

  def project do
    [
      app: :ldns,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: compilers(),
      make_env: %{"MIX_ENV" => to_string(Mix.env())},
      make_executable: "make",
      make_cwd: "c_src",
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
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:elixir_make, "~> 0.9", runtime: false},
      {:jason, "~> 1.4"}
    ]
  end

  defp compilers() do
    [:elixir_make] ++ Mix.compilers()
  end
end

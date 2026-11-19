defmodule Actuator.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :actuator,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      docs: docs()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Actuator.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.15"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:ecto_sqlite3, "~> 0.17"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:gos_ui, github: "imsmith/gos-ui"},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:comn, "~> 0.7.0", github: "imsmith/comn"},
      {:ex_cpn, github: "imsmith/ex_cpn", tag: "v0.1.0"},
      {:ex_yang, github: "imsmith/ex_yang", tag: "v0.3.0"},
      {:yaml_elixir, "~> 2.11"},
      {:busybody_client, "~> 0.1.0", github: "imsmith/busybody-client", only: :dev},
      {:vet_cli, path: Path.expand("~/github/vet/apps/vet_cli"), only: :dev, runtime: false},
      {:sobelow, "~> 0.18", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "ISSUES.md"],
      groups_for_modules: [
        Transducers: [
          Actuator.Transducers,
          Actuator.Transducers.Transducer,
          Actuator.Transducers.Binding,
          Actuator.Transducers.Instances,
          Actuator.Transducers.Action,
          Actuator.Transducers.ListenerSpec,
          Actuator.Transducers.Telemetry
        ],
        "API specs": [Actuator.ApiSpecs, Actuator.ApiSpecs.ApiSpec],
        "Web: listener": [
          ActuatorWeb.TransducerController,
          ActuatorWeb.ListenerSpecController,
          ActuatorWeb.Plugs.ApiAuth
        ],
        "Web: admin": [
          ActuatorWeb.TransducerLive.Index,
          ActuatorWeb.TransducerLive.Show,
          ActuatorWeb.TransducerLive.Form,
          ActuatorWeb.ApiSpecLive.Index,
          ActuatorWeb.ApiSpecLive.Show,
          ActuatorWeb.ApiSpecLive.Form,
          ActuatorWeb.ListenerDocLive
        ],
        Infrastructure: [
          Actuator,
          Actuator.Application,
          Actuator.Repo,
          Actuator.Mailer,
          ActuatorWeb,
          ActuatorWeb.Endpoint,
          ActuatorWeb.Router,
          ActuatorWeb.Telemetry,
          ActuatorWeb.Gettext,
          ActuatorWeb.Layouts,
          ActuatorWeb.CoreComponents,
          ActuatorWeb.PageController,
          ActuatorWeb.PageHTML,
          ActuatorWeb.ErrorHTML,
          ActuatorWeb.ErrorJSON
        ]
      ]
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind actuator", "esbuild actuator"],
      "assets.deploy": [
        "tailwind actuator --minify",
        "esbuild actuator --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"],
      quality: ["credo --strict", "sobelow --skip --exit", "dialyzer"]
    ]
  end
end

# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Gut.Repo.insert!(%Gut.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

actor = Gut.system_actor("seeds")

workshops = [
  {"Intro to Elixir", "Learn the basics of Elixir and functional programming.", 20},
  {"Phoenix LiveView Deep Dive", "Build real-time UIs without JavaScript.", 25},
  {"Building APIs with Ash", "Model your domain and get a full API for free.", 20},
  {"Nerves: Embedded Elixir", "Deploy Elixir to hardware devices with Nerves.", 15},
  {"OTP Patterns in Practice", "Supervisors, GenServers, and fault tolerance.", 30},
  {"Ecto Beyond Basics", "Advanced queries, multi-tenancy, and migrations.", 25},
  {"Testing Elixir Applications", "Property-based testing, mocks, and strategies.", 30},
  {"Machine Learning with Nx", "Numerical computing and ML in Elixir.", 20},
  {"Broadway for Data Pipelines", "Process large volumes of data concurrently.", 20},
  {"Distributed Systems with Elixir", "Clustering, CRDTs, and consistency.", 15},
  {"GraphQL with Absinthe", "Build flexible APIs with GraphQL.", 25},
  {"Deployment & Observability", "Releases, Docker, and production monitoring.", 30},
  {"LiveView Components", "Reusable UI components and design systems.", 25},
  {"Security for Elixir Apps", "Authentication, authorization, and OWASP.", 20},
  {"Concurrency Masterclass", "Tasks, processes, and back-pressure.", 20},
  {"Building CLI Tools", "Command-line applications with Elixir.", 15},
  {"Elixir for Rubyists", "Transition from Ruby/Rails to Elixir/Phoenix.", 30},
  {"Performance Tuning", "Profiling, benchmarking, and optimization.", 20},
  {"Event Sourcing with Commanded", "CQRS and event-driven architectures.", 15},
  {"Elixir in Production", "War stories and lessons from running Elixir at scale.", 25},
  {"WebSockets & Channels", "Real-time communication beyond LiveView.", 20},
  {"Ash Authentication & Authorization", "Secure your Ash resources.", 20},
  {"Contributing to Open Source", "How to contribute to the Elixir ecosystem.", 30},
  {"Functional Design Patterns", "Monads, pipelines, and composition.", 20},
  {"Building a Game Server", "Real-time multiplayer with Elixir.", 15},
  {"Internationalizing Phoenix Apps", "Gettext, locales, and multilingual UIs.", 25},
  {"Oban for Background Jobs", "Reliable job processing with Oban.", 20},
  {"From Monolith to Umbrella", "Structuring large Elixir codebases.", 25},
  {"Debugging & Tracing", "Observer, :dbg, recon, and Entrace.", 20},
  {"Type Specs & Dialyzer", "Static analysis and type checking.", 20}
]

for {name, description, limit} <- workshops do
  Ash.create!(
    Ash.Changeset.for_create(Gut.Conference.Workshop, :create, %{
      name: name,
      description: description,
      limit: limit
    }),
    actor: actor
  )
end

IO.puts("Seeded #{length(workshops)} workshops.")

defmodule Browsergrid.Repo do
  use Ecto.Repo,
    otp_app: :browsergrid,
    adapter: Ecto.Adapters.Postgres
end

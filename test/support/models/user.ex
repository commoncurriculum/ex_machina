defmodule ExMachina.User do
  use Ecto.Schema

  schema "users" do
    field :name, :string
    field :admin, :boolean
    field :net_worth, :decimal

    has_many :articles, ExMachina.Article
  end
end

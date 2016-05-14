defmodule ExMachina.EctoStrategy do
  @moduledoc false

  use ExMachina.Strategy, function_name: :insert

  def handle_insert(%{__meta__: %{state: :loaded}} = record, _) do
    raise "You called `insert` on a record that has already been inserted.
     Make sure that you have not accidentally called insert twice.

     The record you attempted to insert:

     #{inspect record, limit: :infinity}"
  end

  def handle_insert(%{__meta__: %{__struct__: Ecto.Schema.Metadata}} = record, %{repo: repo}) do
    record
    |> build_changeset
    |> repo.insert!
  end

  def handle_insert(record, %{repo: _repo}) do
    raise ArgumentError, "#{inspect record} is not an Ecto model. Use `build` instead"
  end

  def handle_insert(_record, _opts) do
    raise "expected :repo to be given to ExMachina.EctoStrategy"
  end

  defp build_changeset(%{__struct__: model} = record) do
    model
    |> struct
    |> changeset(record |> ExMachina.Ecto.drop_ecto_metadata)
  end

  defp changeset(model, params) do
    fields_to_cast = model
    |> ExMachina.Ecto.drop_ecto_fields
    |> Map.keys

    model
    |> Ecto.Changeset.cast(params, fields_to_cast)
    |> cast_and_put_assocs
  end

  defp cast_and_put_assocs(changeset = %{data: %{__struct__: struct}}) do
    assocs = struct.__schema__(:associations)

    Enum.reduce(assocs, changeset, fn (association_name, changeset) ->
      case get_association(changeset.params, association_name) do
        %Ecto.Association.NotLoaded{} ->
          changeset
        %{__meta__: %{__struct__: Ecto.Schema.Metadata, state: :loaded}} = association ->
          Ecto.Changeset.put_assoc(changeset, association_name, association)
        %{__meta__: %{__struct__: Ecto.Schema.Metadata, state: :built}} = association ->
          changeset
          |> destructure_assoc(association_name, association)
          |> Ecto.Changeset.cast_assoc(association_name, with: &changeset/2)
        _ ->
          Ecto.Changeset.cast_assoc(changeset, association_name, with: &changeset/2)
      end
    end)
  end

  defp get_association(params, association_name) do
    Map.get(params, Atom.to_string(association_name))
  end

  defp destructure_assoc(changeset, association_name, association) do
    record = ExMachina.Ecto.drop_ecto_metadata(association)
    new_params = Map.put(changeset.params, Atom.to_string(association_name), record)

    Map.put(changeset, :params, new_params)
  end
end

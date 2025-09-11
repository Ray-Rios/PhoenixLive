defmodule PhoenixApp.EqemuMigration do
  @moduledoc """
  Main module for EQEMU database migration functionality.
  Provides coordination between different migration components.
  """

  alias PhoenixApp.EqemuMigration.DatabaseAnalyzer

  @doc """
  Analyze the postgres_peq.sql dump file and return comprehensive analysis.
  """
  def analyze_dump(file_path \\ "eqemu/mySQL_to_Postgres_Tool/postgres_peq.sql") do
    DatabaseAnalyzer.analyze_dump(file_path)
  end

  @doc """
  Get information about a specific table from the analysis.
  """
  def get_table_info(table_name) do
    DatabaseAnalyzer.get_table_info(table_name)
  end

  @doc """
  Count rows in a specific table from the dump.
  """
  def count_table_rows(table_name) do
    DatabaseAnalyzer.count_table_rows(table_name)
  end
end
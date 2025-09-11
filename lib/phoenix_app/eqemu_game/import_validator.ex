defmodule PhoenixApp.EQEmuGame.ImportValidator do
  @moduledoc """
  Validation tools to verify PEQ import completeness and data integrity.
  
  This module provides comprehensive validation of imported PEQ data,
  checking for data consistency, referential integrity, and completeness.
  """
  
  alias PhoenixApp.Repo
  import Ecto.Query
  require Logger
  
  defstruct [
    :validation_results,
    :errors,
    :warnings,
    :statistics,
    :start_time,
    :end_time
  ]
  
  def validate_complete_import(_opts \\ []) do
    Logger.info("🔍 Starting comprehensive PEQ import validation...")
    
    validator = %__MODULE__{
      validation_results: %{},
      errors: [],
      warnings: [],
      statistics: %{},
      start_time: DateTime.utc_now(),
      end_time: nil
    }
    
    # Run all validation checks
    validator
    |> validate_table_existence()
    |> validate_data_counts()
    |> validate_referential_integrity()
    |> validate_data_quality()
    |> validate_character_constraints()
    |> validate_item_data()
    |> validate_account_relationships()
    |> validate_guild_system()
    |> validate_zone_data()
    |> generate_validation_report()
    |> finalize_validation()
  end
  
  def validate_table_existence(validator) do
    Logger.info("📋 Validating table existence...")
    
    required_tables = [
      "eqemu_accounts",
      "eqemu_characters", 
      "eqemu_items",
      "eqemu_guilds",
      "eqemu_guild_members",
      "eqemu_zones",
      "eqemu_character_inventory"
    ]
    
    existing_tables = get_existing_tables()
    
    missing_tables = required_tables -- existing_tables
    extra_tables = existing_tables -- required_tables
    
    results = %{
      required: required_tables,
      existing: existing_tables,
      missing: missing_tables,
      extra: extra_tables,
      all_present: length(missing_tables) == 0
    }
    
    # Add errors for missing tables
    errors = 
      missing_tables
      |> Enum.map(&"Missing required table: #{&1}")
    
    # Add warnings for extra tables
    warnings = 
      extra_tables
      |> Enum.map(&"Unexpected table found: #{&1}")
    
    Logger.info("✅ Table validation completed: #{length(existing_tables)} tables found")
    
    if length(missing_tables) > 0 do
      Logger.error("❌ Missing tables: #{Enum.join(missing_tables, ", ")}")
    end
    
    %{validator | 
      validation_results: Map.put(validator.validation_results, :tables, results),
      errors: validator.errors ++ errors,
      warnings: validator.warnings ++ warnings
    }
  end
  
  def validate_data_counts(validator) do
    Logger.info("📊 Validating data counts...")
    
    table_counts = %{
      accounts: count_records("eqemu_accounts"),
      characters: count_records("eqemu_characters"),
      items: count_records("eqemu_items"),
      guilds: count_records("eqemu_guilds"),
      guild_members: count_records("eqemu_guild_members"),
      zones: count_records("eqemu_zones"),
      character_inventory: count_records("eqemu_character_inventory")
    }
    
    # Validate minimum expected counts
    minimum_expectations = %{
      accounts: 1,      # At least 1 account
      characters: 0,    # Characters are optional
      items: 100,       # Should have at least 100 items
      guilds: 0,        # Guilds are optional
      zones: 10         # Should have at least 10 zones
    }
    
    count_errors = 
      minimum_expectations
      |> Enum.filter(fn {table, min_count} -> 
        Map.get(table_counts, table, 0) < min_count 
      end)
      |> Enum.map(fn {table, min_count} ->
        actual = Map.get(table_counts, table, 0)
        "Table #{table} has #{actual} records, expected at least #{min_count}"
      end)
    
    Logger.info("📈 Data counts:")
    Enum.each(table_counts, fn {table, count} ->
      Logger.info("   #{table}: #{count} records")
    end)
    
    %{validator | 
      validation_results: Map.put(validator.validation_results, :counts, table_counts),
      errors: validator.errors ++ count_errors,
      statistics: Map.merge(validator.statistics, table_counts)
    }
  end
  
  def validate_referential_integrity(validator) do
    Logger.info("🔗 Validating referential integrity...")
    
    integrity_checks = [
      check_character_account_references(),
      check_character_inventory_references(),
      check_guild_member_references(),
      check_character_zone_references()
    ]
    
    all_errors = 
      integrity_checks
      |> Enum.flat_map(fn {_check_name, errors} -> errors end)
    
    integrity_results = %{
      checks_performed: length(integrity_checks),
      total_errors: length(all_errors),
      checks: Map.new(integrity_checks)
    }
    
    Logger.info("🔍 Referential integrity: #{length(all_errors)} issues found")
    
    %{validator | 
      validation_results: Map.put(validator.validation_results, :integrity, integrity_results),
      errors: validator.errors ++ all_errors
    }
  end
  
  def validate_data_quality(validator) do
    Logger.info("✨ Validating data quality...")
    
    quality_checks = [
      check_character_name_uniqueness(),
      check_account_name_uniqueness(),
      check_item_name_validity(),
      check_character_stats_validity(),
      check_zone_coordinate_validity()
    ]
    
    all_warnings = 
      quality_checks
      |> Enum.flat_map(fn {_check_name, warnings} -> warnings end)
    
    quality_results = %{
      checks_performed: length(quality_checks),
      total_warnings: length(all_warnings),
      checks: Map.new(quality_checks)
    }
    
    Logger.info("🎯 Data quality: #{length(all_warnings)} warnings found")
    
    %{validator | 
      validation_results: Map.put(validator.validation_results, :quality, quality_results),
      warnings: validator.warnings ++ all_warnings
    }
  end
  
  def validate_character_constraints(validator) do
    Logger.info("🧙 Validating character constraints...")
    
    # Check character limit per account (max 10)
    accounts_over_limit = 
      from(c in "eqemu_characters",
        group_by: c.account_id,
        having: count(c.id) > 10,
        select: {c.account_id, count(c.id)}
      )
      |> Repo.all()
    
    # Check invalid character classes (should be 1-16)
    invalid_classes = 
      from(c in "eqemu_characters",
        where: c.class < 1 or c.class > 16,
        select: {c.id, c.name, c.class}
      )
      |> Repo.all()
    
    # Check invalid character races (should be 1-522)
    invalid_races = 
      from(c in "eqemu_characters",
        where: c.race < 1 or c.race > 522,
        select: {c.id, c.name, c.race}
      )
      |> Repo.all()
    
    constraint_errors = []
    
    constraint_errors = 
      accounts_over_limit
      |> Enum.reduce(constraint_errors, fn {account_id, count}, acc ->
        ["Account #{account_id} has #{count} characters (max 10 allowed)" | acc]
      end)
    
    constraint_errors = 
      invalid_classes
      |> Enum.reduce(constraint_errors, fn {char_id, name, class}, acc ->
        ["Character #{name} (ID: #{char_id}) has invalid class: #{class}" | acc]
      end)
    
    constraint_errors = 
      invalid_races
      |> Enum.reduce(constraint_errors, fn {char_id, name, race}, acc ->
        ["Character #{name} (ID: #{char_id}) has invalid race: #{race}" | acc]
      end)
    
    constraint_results = %{
      accounts_over_character_limit: length(accounts_over_limit),
      invalid_character_classes: length(invalid_classes),
      invalid_character_races: length(invalid_races),
      total_constraint_violations: length(constraint_errors)
    }
    
    Logger.info("⚖️  Character constraints: #{length(constraint_errors)} violations found")
    
    %{validator | 
      validation_results: Map.put(validator.validation_results, :character_constraints, constraint_results),
      errors: validator.errors ++ constraint_errors
    }
  end
  
  def validate_item_data(validator) do
    Logger.info("⚔️ Validating item data...")
    
    # Check for items with invalid damage/delay ratios
    invalid_weapons = 
      from(i in "eqemu_items",
        where: i.damage > 0 and i.delay <= 0,
        select: {i.id, i.name, i.damage, i.delay}
      )
      |> Repo.all()
    
    # Check for items with negative stats
    negative_stats = 
      from(i in "eqemu_items",
        where: i.weight < 0 or i.price < 0,
        select: {i.id, i.name, i.weight, i.price}
      )
      |> Repo.all()
    
    item_warnings = []
    
    item_warnings = 
      invalid_weapons
      |> Enum.reduce(item_warnings, fn {item_id, name, damage, delay}, acc ->
        ["Item #{name} (ID: #{item_id}) has damage #{damage} but delay #{delay}" | acc]
      end)
    
    item_warnings = 
      negative_stats
      |> Enum.reduce(item_warnings, fn {item_id, name, weight, price}, acc ->
        ["Item #{name} (ID: #{item_id}) has negative stats: weight=#{weight}, price=#{price}" | acc]
      end)
    
    item_results = %{
      invalid_weapon_ratios: length(invalid_weapons),
      negative_stat_items: length(negative_stats),
      total_item_issues: length(item_warnings)
    }
    
    Logger.info("🗡️  Item validation: #{length(item_warnings)} issues found")
    
    %{validator | 
      validation_results: Map.put(validator.validation_results, :items, item_results),
      warnings: validator.warnings ++ item_warnings
    }
  end
  
  def validate_account_relationships(validator) do
    Logger.info("👤 Validating account relationships...")
    
    # Check for EQEmu accounts without Phoenix users
    orphaned_accounts = 
      from(a in "eqemu_accounts",
        left_join: u in "users", on: a.user_id == u.id,
        where: is_nil(u.id),
        select: {a.id, a.name}
      )
      |> Repo.all()
    
    # Check for duplicate account names
    duplicate_names = 
      from(a in "eqemu_accounts",
        group_by: a.name,
        having: count(a.id) > 1,
        select: {a.name, count(a.id)}
      )
      |> Repo.all()
    
    account_errors = []
    
    account_errors = 
      orphaned_accounts
      |> Enum.reduce(account_errors, fn {account_id, name}, acc ->
        ["EQEmu account #{name} (ID: #{account_id}) has no linked Phoenix user" | acc]
      end)
    
    account_errors = 
      duplicate_names
      |> Enum.reduce(account_errors, fn {name, count}, acc ->
        ["Duplicate account name '#{name}' found #{count} times" | acc]
      end)
    
    account_results = %{
      orphaned_accounts: length(orphaned_accounts),
      duplicate_account_names: length(duplicate_names),
      total_account_issues: length(account_errors)
    }
    
    Logger.info("🔐 Account validation: #{length(account_errors)} issues found")
    
    %{validator | 
      validation_results: Map.put(validator.validation_results, :accounts, account_results),
      errors: validator.errors ++ account_errors
    }
  end
  
  def validate_guild_system(validator) do
    Logger.info("🏰 Validating guild system...")
    
    # Check for guild members without valid characters
    invalid_guild_members = 
      from(gm in "eqemu_guild_members",
        left_join: c in "eqemu_characters", on: gm.char_id == c.id,
        where: is_nil(c.id),
        select: {gm.id, gm.char_id, gm.guild_id}
      )
      |> Repo.all()
    
    # Check for guilds without leaders
    leaderless_guilds = 
      from(g in "eqemu_guilds",
        left_join: c in "eqemu_characters", on: g.leader == c.id,
        where: is_nil(c.id),
        select: {g.id, g.name, g.leader}
      )
      |> Repo.all()
    
    guild_warnings = []
    
    guild_warnings = 
      invalid_guild_members
      |> Enum.reduce(guild_warnings, fn {member_id, char_id, guild_id}, acc ->
        ["Guild member #{member_id} references non-existent character #{char_id} in guild #{guild_id}" | acc]
      end)
    
    guild_warnings = 
      leaderless_guilds
      |> Enum.reduce(guild_warnings, fn {guild_id, name, leader_id}, acc ->
        ["Guild #{name} (ID: #{guild_id}) has invalid leader ID: #{leader_id}" | acc]
      end)
    
    guild_results = %{
      invalid_guild_members: length(invalid_guild_members),
      leaderless_guilds: length(leaderless_guilds),
      total_guild_issues: length(guild_warnings)
    }
    
    Logger.info("👑 Guild validation: #{length(guild_warnings)} issues found")
    
    %{validator | 
      validation_results: Map.put(validator.validation_results, :guilds, guild_results),
      warnings: validator.warnings ++ guild_warnings
    }
  end
  
  def validate_zone_data(validator) do
    Logger.info("🗺️ Validating zone data...")
    
    # Check for zones with invalid coordinates
    invalid_coordinates = 
      from(z in "eqemu_zones",
        where: is_nil(z.safe_x) or is_nil(z.safe_y) or is_nil(z.safe_z),
        select: {z.id, z.short_name, z.safe_x, z.safe_y, z.safe_z}
      )
      |> Repo.all()
    
    # Check for duplicate zone short names
    duplicate_zones = 
      from(z in "eqemu_zones",
        group_by: z.short_name,
        having: count(z.id) > 1,
        select: {z.short_name, count(z.id)}
      )
      |> Repo.all()
    
    zone_warnings = []
    
    zone_warnings = 
      invalid_coordinates
      |> Enum.reduce(zone_warnings, fn {zone_id, short_name, x, y, z}, acc ->
        ["Zone #{short_name} (ID: #{zone_id}) has invalid safe coordinates: (#{x}, #{y}, #{z})" | acc]
      end)
    
    zone_warnings = 
      duplicate_zones
      |> Enum.reduce(zone_warnings, fn {short_name, count}, acc ->
        ["Duplicate zone short name '#{short_name}' found #{count} times" | acc]
      end)
    
    zone_results = %{
      invalid_coordinates: length(invalid_coordinates),
      duplicate_zone_names: length(duplicate_zones),
      total_zone_issues: length(zone_warnings)
    }
    
    Logger.info("🌍 Zone validation: #{length(zone_warnings)} issues found")
    
    %{validator | 
      validation_results: Map.put(validator.validation_results, :zones, zone_results),
      warnings: validator.warnings ++ zone_warnings
    }
  end
  
  def generate_validation_report(validator) do
    Logger.info("📋 Generating validation report...")
    
    report_content = """
    # PEQ Import Validation Report
    Generated: #{DateTime.to_string(validator.start_time)}
    
    ## Summary
    - Total Errors: #{length(validator.errors)}
    - Total Warnings: #{length(validator.warnings)}
    - Validation Status: #{if length(validator.errors) == 0, do: "✅ PASSED", else: "❌ FAILED"}
    
    ## Statistics
    #{format_statistics(validator.statistics)}
    
    ## Validation Results
    #{format_validation_results(validator.validation_results)}
    
    ## Errors
    #{format_issues(validator.errors, "❌")}
    
    ## Warnings  
    #{format_issues(validator.warnings, "⚠️")}
    
    ## Recommendations
    #{generate_recommendations(validator)}
    """
    
    # Write report to file
    report_file = "tmp/eqemu_migration/validation_report_#{DateTime.to_unix(validator.start_time)}.md"
    File.mkdir_p!(Path.dirname(report_file))
    File.write!(report_file, report_content)
    
    Logger.info("📄 Validation report saved: #{report_file}")
    
    %{validator | 
      validation_results: Map.put(validator.validation_results, :report_file, report_file)
    }
  end
  
  def finalize_validation(validator) do
    end_time = DateTime.utc_now()
    total_time = DateTime.diff(end_time, validator.start_time, :second)
    
    final_validator = %{validator | end_time: end_time}
    
    Logger.info("🎯 Validation completed in #{total_time} seconds")
    Logger.info("📊 Final Results:")
    Logger.info("   ❌ Errors: #{length(validator.errors)}")
    Logger.info("   ⚠️  Warnings: #{length(validator.warnings)}")
    
    status = if length(validator.errors) == 0, do: :passed, else: :failed
    
    Logger.info("   🎖️  Status: #{String.upcase(to_string(status))}")
    
    {status, final_validator}
  end
  
  # Helper functions for validation checks
  
  defp get_existing_tables do
    query = """
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name LIKE 'eqemu_%'
    """
    
    case Repo.query(query) do
      {:ok, %{rows: rows}} -> Enum.map(rows, &List.first/1)
      _ -> []
    end
  end
  
  defp count_records(table_name) do
    try do
      Repo.one!(from t in table_name, select: count())
    rescue
      _ -> 0
    end
  end
  
  defp check_character_account_references do
    orphaned_characters = 
      from(c in "eqemu_characters",
        left_join: a in "eqemu_accounts", on: c.account_id == a.id,
        where: is_nil(a.id),
        select: {c.id, c.name, c.account_id}
      )
      |> Repo.all()
    
    errors = 
      orphaned_characters
      |> Enum.map(fn {char_id, name, account_id} ->
        "Character #{name} (ID: #{char_id}) references non-existent account #{account_id}"
      end)
    
    {"character_account_references", errors}
  end
  
  defp check_character_inventory_references do
    # This would check character_inventory table if it exists
    {"character_inventory_references", []}
  end
  
  defp check_guild_member_references do
    invalid_members = 
      from(gm in "eqemu_guild_members",
        left_join: c in "eqemu_characters", on: gm.char_id == c.id,
        left_join: g in "eqemu_guilds", on: gm.guild_id == g.id,
        where: is_nil(c.id) or is_nil(g.id),
        select: {gm.id, gm.char_id, gm.guild_id}
      )
      |> Repo.all()
    
    errors = 
      invalid_members
      |> Enum.map(fn {member_id, char_id, guild_id} ->
        "Guild member #{member_id} has invalid references: char_id=#{char_id}, guild_id=#{guild_id}"
      end)
    
    {"guild_member_references", errors}
  end
  
  defp check_character_zone_references do
    invalid_zones = 
      from(c in "eqemu_characters",
        left_join: z in "eqemu_zones", on: c.zone_id == z.id,
        where: is_nil(z.id),
        select: {c.id, c.name, c.zone_id}
      )
      |> Repo.all()
    
    errors = 
      invalid_zones
      |> Enum.map(fn {char_id, name, zone_id} ->
        "Character #{name} (ID: #{char_id}) references non-existent zone #{zone_id}"
      end)
    
    {"character_zone_references", errors}
  end
  
  defp check_character_name_uniqueness do
    duplicates = 
      from(c in "eqemu_characters",
        group_by: c.name,
        having: count(c.id) > 1,
        select: {c.name, count(c.id)}
      )
      |> Repo.all()
    
    warnings = 
      duplicates
      |> Enum.map(fn {name, count} ->
        "Duplicate character name '#{name}' found #{count} times"
      end)
    
    {"character_name_uniqueness", warnings}
  end
  
  defp check_account_name_uniqueness do
    duplicates = 
      from(a in "eqemu_accounts",
        group_by: a.name,
        having: count(a.id) > 1,
        select: {a.name, count(a.id)}
      )
      |> Repo.all()
    
    warnings = 
      duplicates
      |> Enum.map(fn {name, count} ->
        "Duplicate account name '#{name}' found #{count} times"
      end)
    
    {"account_name_uniqueness", warnings}
  end
  
  defp check_item_name_validity do
    invalid_names = 
      from(i in "eqemu_items",
        where: is_nil(i.name) or i.name == "",
        select: {i.id, i.name}
      )
      |> Repo.all()
    
    warnings = 
      invalid_names
      |> Enum.map(fn {item_id, name} ->
        "Item ID #{item_id} has invalid name: '#{name}'"
      end)
    
    {"item_name_validity", warnings}
  end
  
  defp check_character_stats_validity do
    invalid_stats = 
      from(c in "eqemu_characters",
        where: c.level < 1 or c.level > 65 or c.hp <= 0,
        select: {c.id, c.name, c.level, c.hp}
      )
      |> Repo.all()
    
    warnings = 
      invalid_stats
      |> Enum.map(fn {char_id, name, level, hp} ->
        "Character #{name} (ID: #{char_id}) has invalid stats: level=#{level}, hp=#{hp}"
      end)
    
    {"character_stats_validity", warnings}
  end
  
  defp check_zone_coordinate_validity do
    {"zone_coordinate_validity", []}
  end
  
  # Report formatting functions
  
  defp format_statistics(statistics) do
    statistics
    |> Enum.map(fn {key, value} -> "- #{key}: #{value}" end)
    |> Enum.join("\n")
  end
  
  defp format_validation_results(results) do
    results
    |> Enum.map(fn {section, data} ->
      "### #{String.capitalize(to_string(section))}\n#{inspect(data, pretty: true)}"
    end)
    |> Enum.join("\n\n")
  end
  
  defp format_issues(issues, icon) do
    if length(issues) == 0 do
      "None"
    else
      issues
      |> Enum.map(&"#{icon} #{&1}")
      |> Enum.join("\n")
    end
  end
  
  defp generate_recommendations(validator) do
    recommendations = []
    
    recommendations = 
      if length(validator.errors) > 0 do
        ["- Fix all errors before proceeding with EQEmu server integration" | recommendations]
      else
        recommendations
      end
    
    recommendations = 
      if Map.get(validator.statistics, :characters, 0) == 0 do
        ["- Consider importing some test characters for development" | recommendations]
      else
        recommendations
      end
    
    recommendations = 
      if Map.get(validator.statistics, :items, 0) < 1000 do
        ["- Import more items for a complete gaming experience" | recommendations]
      else
        recommendations
      end
    
    if length(recommendations) == 0 do
      "- Import validation passed! Ready for EQEmu integration."
    else
      Enum.join(recommendations, "\n")
    end
  end
end
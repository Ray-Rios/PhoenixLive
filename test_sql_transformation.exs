#!/usr/bin/env elixir

# Test script for SQL transformation
# This will transform the postgres_peq.sql file to match Phoenix schema

# Load the Phoenix application
Mix.install([])

# Add the lib directory to the code path
Code.append_path("lib")

# Compile and load the modules
Code.compile_file("lib/phoenix_app/eqemu_migration/sql_transformer.ex")
Code.compile_file("lib/phoenix_app/eqemu_migration/cli.ex")

# Load the required modules
alias PhoenixApp.EqemuMigration.CLI

IO.puts("🚀 Testing SQL Transformation for Phoenix Compatibility")
IO.puts("=" |> String.duplicate(60))

# Run the SQL transformation
CLI.transform_sql()

IO.puts("\n🎯 Next Steps:")
IO.puts("1. Review the generated postgres_peq_phoenix.sql file")
IO.puts("2. Import it into your Phoenix database:")
IO.puts("   docker-compose exec db psql -U postgres -d phoenix_app_dev -f /path/to/postgres_peq_phoenix.sql")
IO.puts("3. Test Phoenix application with the migrated data")
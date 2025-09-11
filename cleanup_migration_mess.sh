#!/bin/bash

# Clean up the EQEmu migration mess
# Remove all the broken files and complex tools that don't work

echo "🧹 Cleaning up EQEmu migration mess..."
echo "====================================="

# Remove broken SQL files
echo "🗑️  Removing broken SQL files..."
rm -f eqemu/mySQL_to_Postgres_Tool/postgres_peq_minimal.sql
rm -f eqemu/mySQL_to_Postgres_Tool/postgres_peq_trimmed.sql
rm -f eqemu/mySQL_to_Postgres_Tool/postgres_peq_fixed.sql
rm -f eqemu/mySQL_to_Postgres_Tool/postgres_clean_import.sql
rm -f eqemu/mySQL_to_Postgres_Tool/phoenix_import_ready.sql
rm -f eqemu/mySQL_to_Postgres_Tool/phoenix_direct_edit.sql
rm -f eqemu/mySQL_to_Postgres_Tool/phoenix_import.sql

# Remove broken migration tools
echo "🗑️  Removing overly complex migration tools..."
rm -f lib/phoenix_app/eqemu_migration/advanced_trimmer.ex
rm -f lib/phoenix_app/eqemu_migration/aggressive_trimmer.ex
rm -f lib/phoenix_app/eqemu_migration/import_preparer.ex
rm -f lib/phoenix_app/eqemu_migration/sql_transformer.ex
rm -f lib/phoenix_app/eqemu_migration/data_importer.ex
rm -f lib/phoenix_app/eqemu_migration/trim_cli.ex
rm -f lib/phoenix_app/eqemu_migration/aggressive_trim_cli.ex
rm -f lib/phoenix_app/eqemu_migration/import_prep_cli.ex
rm -f lib/phoenix_app/eqemu_migration/import_cli.ex

# Remove broken import scripts
echo "🗑️  Removing broken import scripts..."
rm -f import_eqemu_data.sh
rm -f import_eqemu_clean.sh
rm -f import_eqemu_fixed.sh
rm -f fix_sql_properly.sh

# Remove backup directories with broken files
echo "🗑️  Removing backup directories..."
rm -rf eqemu/backups

# Remove documentation of failures
echo "🗑️  Removing failure documentation..."
rm -f AI_Docs/DATABASE_TRIMMING_COMPLETE.md
rm -f AI_Docs/SQL_IMPORT_PREPARATION_COMPLETE.md
rm -f MIGRATION_FAILURE_ANALYSIS.md
rm -f EQEMU_MIGRATION_CLEAN.md

# Remove the entire eqemu migration spec since we're abandoning it
echo "🗑️  Removing abandoned EQEmu migration spec..."
rm -rf .kiro/specs/eqemu-database-migration

# Keep only essential tools that might be useful
echo "✅ Keeping useful tools:"
echo "   • lib/phoenix_app/eqemu_migration/cli.ex - Main CLI interface"
echo "   • lib/phoenix_app/eqemu_migration/database_analyzer.ex - Database analysis"
echo "   • lib/phoenix_app/eqemu_migration/row_counter.ex - Row counting"
echo "   • lib/phoenix_app/eqemu_migration/table_inspector.ex - Table inspection"
echo "   • lib/phoenix_app/eqemu_migration/table_filter.ex - Table filtering"

# Clean up test files
echo "🗑️  Removing test files..."
rm -f test_migration.exs
rm -f test/phoenix_app/eqemu_migration/database_analyzer_test.exs

echo ""
echo "🎉 Cleanup Complete!"
echo "=================="
echo "✅ Removed all broken migration files"
echo "✅ Removed overly complex tools"
echo "✅ Removed failed import scripts"
echo "✅ Kept essential analysis tools"
echo ""
echo "🚀 Ready to focus on:"
echo "   • Clean Phoenix schema evolution"
echo "   • Proper migration file management"
echo "   • UE5 game development"
echo ""
echo "Next steps:"
echo "1. Start CockroachDB: docker-compose up -d"
echo "2. Focus on Phoenix schema design"
echo "3. Build your UE5 game with clean data structures"
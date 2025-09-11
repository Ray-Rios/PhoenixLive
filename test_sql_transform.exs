# Simple test for SQL transformation within Phoenix environment

alias PhoenixApp.EqemuMigration.SqlTransformer

IO.puts("🚀 Testing SQL Transformation for Phoenix Compatibility")
IO.puts("=" |> String.duplicate(60))

# Test the transformation
case SqlTransformer.run_transformation() do
  {:ok, result} ->
    IO.puts("✅ SQL transformation completed successfully!")
    IO.puts("📁 Input file: #{result.input}")
    IO.puts("📁 Output file: #{result.output}")
    IO.puts("🎯 Ready to import the transformed SQL file")
    
  {:error, reason} ->
    IO.puts("❌ SQL transformation failed: #{inspect(reason)}")
end

IO.puts("\n🎯 Next Steps:")
IO.puts("1. Review the generated postgres_peq_phoenix.sql file")
IO.puts("2. Import it into your Phoenix database")
IO.puts("3. Test Phoenix application with the migrated data")
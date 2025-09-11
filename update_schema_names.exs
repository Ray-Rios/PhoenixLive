#!/usr/bin/env elixir

# Script to update all eqemu_ prefixed references in the codebase

files_to_update = [
  "lib/phoenix_app_web/schema/eqemu_types.ex",
  "lib/phoenix_app_web/resolvers/eqemu_resolver.ex",
  "lib/phoenix_app/eqemu_game.ex"
]

# Define the replacements
replacements = [
  # Object types
  {":eqemu_character", ":character"},
  {":eqemu_character_stats", ":character_stats"},
  {":eqemu_item", ":item"},
  {":eqemu_character_inventory", ":character_inventory"},
  {":eqemu_guild", ":guild"},
  {":eqemu_guild_member", ":guild_member"},
  {":eqemu_zone", ":zone"},
  {":eqemu_npc", ":npc"},
  {":eqemu_npc_spawn", ":npc_spawn"},
  {":eqemu_spell", ":spell"},
  {":eqemu_task", ":task"},
  {":eqemu_character_task", ":character_task"},
  
  # Input types
  {":eqemu_character_input", ":character_input"},
  {":eqemu_character_update_input", ":character_update_input"},
  {":eqemu_inventory_update_input", ":inventory_update_input"},
  
  # Query fields
  {"eqemu_character", "character"},
  {"my_eqemu_characters", "my_characters"},
  {"eqemu_character_inventory", "character_inventory"},
  {"eqemu_items", "items"},
  {"eqemu_item", "item"},
  {"eqemu_zones", "zones"},
  {"eqemu_zone", "zone"},
  {"eqemu_guild", "guild"},
  {"eqemu_character_guild", "character_guild"},
  
  # Object names
  {"object :eqemu_queries", "object :eqemu_queries"}, # Keep this one
]

Enum.each(files_to_update, fn file_path ->
  if File.exists?(file_path) do
    IO.puts("Updating #{file_path}...")
    
    content = File.read!(file_path)
    
    updated_content = Enum.reduce(replacements, content, fn {old, new}, acc ->
      String.replace(acc, old, new)
    end)
    
    File.write!(file_path, updated_content)
    IO.puts("✅ Updated #{file_path}")
  else
    IO.puts("⚠️  File not found: #{file_path}")
  end
end)

IO.puts("\n🎉 Schema name updates complete!")
IO.puts("Next steps:")
IO.puts("1. Run the migration: mix ecto.migrate")
IO.puts("2. Update any remaining references in resolvers and contexts")
IO.puts("3. Test the GraphQL schema")
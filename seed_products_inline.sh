#!/bin/bash
# Quick inline seed script for digital products

POD="phoenix-web-5fbd4bbbdc-7rzld"
NAMESPACE="phoenixapp"

echo "🌱 Seeding digital products..."

# Create Basic Monthly subscription
MSYS_NO_PATHCONV=1 kubectl exec -n $NAMESPACE $POD -- /app/bin/phoenix_app rpc '
import Ecto.Query
alias PhoenixApp.Repo
alias PhoenixApp.Commerce.Product

# Deactivate old dummy products
Repo.update_all(from(p in Product, where: p.sku in ["WGH-001", "MGK-002", "4KW-003", "WM-004", "GM27-006", "UCH-007"]), set: [is_active: false])

# Basic Monthly Plan
case Repo.get_by(Product, sku: "PLAN-BASIC-MONTHLY") do
  nil ->
    %Product{}
    |> Product.changeset(%{
      name: "Basic Plan",
      description: "Perfect for personal use. More storage and features.",
      price: Decimal.new("5.00"),
      sku: "PLAN-BASIC-MONTHLY",
      product_type: "subscription",
      billing_interval: "monthly",
      is_active: true,
      stock_quantity: 999999,
      sort_order: 2,
      trial_days: 7,
      grants_storage_bytes: 10_737_418_240,
      grants_role: "basic",
      grants_features: ["basic_uploads", "public_profile", "priority_support", "custom_themes"]
    })
    |> Repo.insert!()
    IO.puts("✅ Created: Basic Plan")
  existing ->
    existing
    |> Product.changeset(%{is_active: true, price: Decimal.new("5.00")})
    |> Repo.update!()
    IO.puts("🔄 Updated: Basic Plan")
end
'

echo ""
echo "Creating Pro Monthly Plan..."
MSYS_NO_PATHCONV=1 kubectl exec -n $NAMESPACE $POD -- /app/bin/phoenix_app rpc '
import Ecto.Query
alias PhoenixApp.Repo
alias PhoenixApp.Commerce.Product

case Repo.get_by(Product, sku: "PLAN-PRO-MONTHLY") do
  nil ->
    %Product{}
    |> Product.changeset(%{
      name: "Pro Plan",
      description: "For power users and creators. Massive storage and all features.",
      price: Decimal.new("15.00"),
      sku: "PLAN-PRO-MONTHLY",
      product_type: "subscription",
      billing_interval: "monthly",
      is_active: true,
      featured: true,
      stock_quantity: 999999,
      sort_order: 4,
      trial_days: 14,
      badge_text: "MOST POPULAR",
      grants_storage_bytes: 107_374_182_400,
      grants_role: "editor",
      grants_features: ["basic_uploads", "public_profile", "priority_support", "custom_themes", "advanced_editor", "api_access", "analytics_dashboard", "collaboration_tools"]
    })
    |> Repo.insert!()
    IO.puts("✅ Created: Pro Plan")
  existing ->
    existing
    |> Product.changeset(%{is_active: true, featured: true, badge_text: "MOST POPULAR"})
    |> Repo.update!()
    IO.puts("🔄 Updated: Pro Plan")
end
'

echo ""
echo "Creating 5GB Storage Add-on..."
MSYS_NO_PATHCONV=1 kubectl exec -n $NAMESPACE $POD -- /app/bin/phoenix_app rpc '
import Ecto.Query
alias PhoenixApp.Repo
alias PhoenixApp.Commerce.Product

case Repo.get_by(Product, sku: "STORAGE-5GB") do
  nil ->
    %Product{}
    |> Product.changeset(%{
      name: "Extra 5GB Storage",
      description: "Add 5GB of additional storage to your account. One-time purchase, permanent addition.",
      price: Decimal.new("3.99"),
      sku: "STORAGE-5GB",
      product_type: "digital",
      billing_interval: "one_time",
      is_active: true,
      stock_quantity: 999999,
      sort_order: 10,
      grants_storage_bytes: 5_368_709_120
    })
    |> Repo.insert!()
    IO.puts("✅ Created: Extra 5GB Storage")
  existing ->
    existing
    |> Product.changeset(%{is_active: true})
    |> Repo.update!()
    IO.puts("🔄 Updated: Extra 5GB Storage")
end
'

echo ""
echo "✅ Digital products seeding complete!"
echo ""
echo "Run this to verify:"
echo "kubectl exec -n $NAMESPACE $POD -- /app/bin/phoenix_app rpc 'PhoenixApp.Commerce.list_products() |> Enum.map(fn p -> p.name end) |> IO.inspect()'"

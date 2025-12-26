# Seeds for digital products and subscription tiers
# Run with: mix run priv/repo/seeds/digital_products.exs

import Ecto.Query
alias PhoenixApp.Repo
alias PhoenixApp.Commerce.Product

IO.puts("🌱 Seeding digital products and subscription tiers...")

# First, deactivate any existing dummy products
Repo.update_all(
  from(p in Product, where: p.sku in ["WGH-001", "MGK-002", "4KW-003", "WM-004", "GM27-006", "UCH-007"]),
  set: [is_active: false]
)

# Helper to create or update product
defmodule Seeds.ProductHelper do
  alias PhoenixApp.Repo
  alias PhoenixApp.Commerce.Product
  
  def upsert_product(attrs) do
    case Repo.get_by(Product, sku: attrs.sku) do
      nil ->
        %Product{}
        |> Product.changeset(attrs)
        |> Repo.insert!()
        |> tap(fn p -> IO.puts("  ✅ Created: #{p.name}") end)
      
      existing ->
        existing
        |> Product.changeset(attrs)
        |> Repo.update!()
        |> tap(fn p -> IO.puts("  🔄 Updated: #{p.name}") end)
    end
  end
end

# =============================================================================
# SUBSCRIPTION TIERS
# =============================================================================

IO.puts("\n📦 Creating subscription tiers...")

# Free Tier (for reference/comparison, not purchasable)
Seeds.ProductHelper.upsert_product(%{
  name: "Free Plan",
  description: "Get started with basic features. 1GB storage included.",
  price: Decimal.new("0.00"),
  sku: "PLAN-FREE",
  product_type: "subscription",
  billing_interval: "monthly",
  is_active: true,
  stock_quantity: 999999,
  sort_order: 1,
  grants_storage_bytes: 1_073_741_824,  # 1 GB
  grants_role: nil,
  grants_features: ["basic_uploads", "public_profile"]
})

# Basic Tier - $5/month
Seeds.ProductHelper.upsert_product(%{
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
  grants_storage_bytes: 10_737_418_240,  # 10 GB
  grants_role: "basic",
  grants_features: ["basic_uploads", "public_profile", "priority_support", "custom_themes"]
})

# Basic Yearly - $50/year (save $10)
Seeds.ProductHelper.upsert_product(%{
  name: "Basic Plan (Yearly)",
  description: "Perfect for personal use. More storage and features. Save $10/year!",
  price: Decimal.new("50.00"),
  sku: "PLAN-BASIC-YEARLY",
  product_type: "subscription",
  billing_interval: "yearly",
  is_active: true,
  stock_quantity: 999999,
  sort_order: 3,
  badge_text: "SAVE $10",
  grants_storage_bytes: 10_737_418_240,  # 10 GB
  grants_role: "basic",
  grants_features: ["basic_uploads", "public_profile", "priority_support", "custom_themes"]
})

# Pro Tier - $15/month
Seeds.ProductHelper.upsert_product(%{
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
  grants_storage_bytes: 107_374_182_400,  # 100 GB
  grants_role: "editor",
  grants_features: [
    "basic_uploads",
    "public_profile", 
    "priority_support",
    "custom_themes",
    "advanced_editor",
    "api_access",
    "analytics_dashboard",
    "collaboration_tools"
  ]
})

# Pro Yearly - $150/year (save $30)
Seeds.ProductHelper.upsert_product(%{
  name: "Pro Plan (Yearly)",
  description: "For power users and creators. Massive storage and all features. Save $30/year!",
  price: Decimal.new("150.00"),
  sku: "PLAN-PRO-YEARLY",
  product_type: "subscription",
  billing_interval: "yearly",
  is_active: true,
  stock_quantity: 999999,
  sort_order: 5,
  badge_text: "BEST VALUE",
  grants_storage_bytes: 107_374_182_400,  # 100 GB
  grants_role: "editor",
  grants_features: [
    "basic_uploads",
    "public_profile", 
    "priority_support",
    "custom_themes",
    "advanced_editor",
    "api_access",
    "analytics_dashboard",
    "collaboration_tools"
  ]
})

# =============================================================================
# STORAGE ADD-ONS (One-time purchases)
# =============================================================================

IO.puts("\n💾 Creating storage add-ons...")

Seeds.ProductHelper.upsert_product(%{
  name: "Extra 5GB Storage",
  description: "Add 5GB of additional storage to your account. One-time purchase, permanent addition.",
  price: Decimal.new("3.99"),
  sku: "STORAGE-5GB",
  product_type: "digital",
  billing_interval: "one_time",
  is_active: true,
  stock_quantity: 999999,
  sort_order: 10,
  grants_storage_bytes: 5_368_709_120  # 5 GB
})

Seeds.ProductHelper.upsert_product(%{
  name: "Extra 25GB Storage",
  description: "Add 25GB of additional storage to your account. One-time purchase, permanent addition.",
  price: Decimal.new("14.99"),
  sku: "STORAGE-25GB",
  product_type: "digital",
  billing_interval: "one_time",
  is_active: true,
  stock_quantity: 999999,
  sort_order: 11,
  badge_text: "POPULAR",
  grants_storage_bytes: 26_843_545_600  # 25 GB
})

Seeds.ProductHelper.upsert_product(%{
  name: "Extra 100GB Storage",
  description: "Add 100GB of additional storage to your account. One-time purchase, permanent addition.",
  price: Decimal.new("49.99"),
  sku: "STORAGE-100GB",
  product_type: "digital",
  billing_interval: "one_time",
  is_active: true,
  stock_quantity: 999999,
  sort_order: 12,
  grants_storage_bytes: 107_374_182_400  # 100 GB
})

# =============================================================================
# DIGITAL DOWNLOADS
# =============================================================================

IO.puts("\n📥 Creating digital download products...")

Seeds.ProductHelper.upsert_product(%{
  name: "Custom Theme Pack",
  description: "A collection of 10 premium custom themes for your desktop and profile.",
  price: Decimal.new("9.99"),
  sku: "DIGITAL-THEMES-01",
  product_type: "digital",
  billing_interval: "one_time",
  is_active: true,
  stock_quantity: 999999,
  sort_order: 20,
  download_limit: 5,
  grants_features: ["premium_themes"]
})

Seeds.ProductHelper.upsert_product(%{
  name: "Icon Pack - Minimal",
  description: "200+ minimal icons for your desktop experience.",
  price: Decimal.new("4.99"),
  sku: "DIGITAL-ICONS-01",
  product_type: "digital",
  billing_interval: "one_time",
  is_active: true,
  stock_quantity: 999999,
  sort_order: 21,
  download_limit: 3
})

# =============================================================================
# LIFETIME DEALS
# =============================================================================

IO.puts("\n⭐ Creating lifetime deals...")

Seeds.ProductHelper.upsert_product(%{
  name: "Lifetime Pro Access",
  description: "Get Pro features forever with a single payment. No recurring fees, ever.",
  price: Decimal.new("299.00"),
  sku: "LIFETIME-PRO",
  product_type: "subscription",
  billing_interval: "lifetime",
  is_active: true,
  featured: true,
  stock_quantity: 100,
  sort_order: 100,
  badge_text: "LIMITED OFFER",
  grants_storage_bytes: 214_748_364_800,  # 200 GB
  grants_role: "editor",
  grants_features: [
    "basic_uploads",
    "public_profile", 
    "priority_support",
    "custom_themes",
    "advanced_editor",
    "api_access",
    "analytics_dashboard",
    "collaboration_tools",
    "lifetime_member_badge",
    "early_access_features"
  ]
})

IO.puts("\n✅ Digital products seeding complete!")
IO.puts("   Run 'mix ecto.migrate' first if you haven't already.\n")

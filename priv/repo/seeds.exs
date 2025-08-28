# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     PhoenixApp.Repo.insert!(%PhoenixApp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias PhoenixApp.Repo
alias PhoenixApp.Commerce.{Category, Product}
alias PhoenixApp.Content.Post
alias PhoenixApp.Chat.Channel

# Clear existing data
Repo.delete_all(Product)
Repo.delete_all(Category)
Repo.delete_all(Post)
Repo.delete_all(Channel)

# Create Categories
tech_category = Repo.insert!(%Category{
  name: "Technology",
  slug: "technology",
  description: "Latest tech gadgets and accessories"
})

gaming_category = Repo.insert!(%Category{
  name: "Gaming",
  slug: "gaming", 
  description: "Gaming gear and accessories"
})

books_category = Repo.insert!(%Category{
  name: "Books",
  slug: "books",
  description: "Digital and physical books"
})

# Create Products
products = [
  %{
    name: "Wireless Gaming Headset",
    description: "High-quality wireless gaming headset with 7.1 surround sound and noise cancellation. Perfect for long gaming sessions.",
    price: Decimal.new("149.99"),
    sku: "WGH-001",
    stock_quantity: 25,
    category_id: gaming_category.id,
    is_active: true,
    weight: 1.2,
    dimensions: "8.5 x 7.2 x 3.8 inches"
  },
  %{
    name: "Mechanical Gaming Keyboard",
    description: "RGB backlit mechanical keyboard with Cherry MX switches. Customizable lighting and programmable keys.",
    price: Decimal.new("199.99"),
    sku: "MGK-002",
    stock_quantity: 15,
    category_id: gaming_category.id,
    is_active: true,
    weight: 2.1,
    dimensions: "17.3 x 5.1 x 1.4 inches"
  },
  %{
    name: "4K Webcam",
    description: "Ultra HD 4K webcam with auto-focus and built-in microphone. Perfect for streaming and video calls.",
    price: Decimal.new("89.99"),
    sku: "4KW-003",
    stock_quantity: 30,
    category_id: tech_category.id,
    is_active: true,
    weight: 0.5,
    dimensions: "4.3 x 2.4 x 2.4 inches"
  },
  %{
    name: "Wireless Mouse",
    description: "Ergonomic wireless mouse with precision tracking and long battery life. Suitable for work and gaming.",
    price: Decimal.new("49.99"),
    sku: "WM-004",
    stock_quantity: 50,
    category_id: tech_category.id,
    is_active: true,
    weight: 0.3,
    dimensions: "4.9 x 2.6 x 1.6 inches"
  },
  %{
    name: "Programming Guide: Elixir",
    description: "Comprehensive guide to learning Elixir programming language. From basics to advanced concepts.",
    price: Decimal.new("39.99"),
    sku: "PGE-005",
    stock_quantity: 100,
    category_id: books_category.id,
    is_active: true,
    weight: 0.8,
    dimensions: "9.2 x 7.5 x 1.2 inches"
  },
  %{
    name: "Gaming Monitor 27\"",
    description: "27-inch 144Hz gaming monitor with 1ms response time and G-Sync compatibility. Perfect for competitive gaming.",
    price: Decimal.new("299.99"),
    sku: "GM27-006",
    stock_quantity: 12,
    category_id: gaming_category.id,
    is_active: true,
    weight: 8.5,
    dimensions: "24.1 x 14.3 x 8.7 inches"
  },
  %{
    name: "USB-C Hub",
    description: "Multi-port USB-C hub with HDMI, USB 3.0, and SD card reader. Expand your laptop connectivity.",
    price: Decimal.new("59.99"),
    sku: "UCH-007",
    stock_quantity: 40,
    category_id: tech_category.id,
    is_active: true,
    weight: 0.4,
    dimensions: "4.7 x 2.0 x 0.6 inches"
  },
  %{
    name: "Gaming Chair",
    description: "Ergonomic gaming chair with lumbar support and adjustable armrests. Comfortable for long sessions.",
    price: Decimal.new("249.99"),
    sku: "GC-008",
    stock_quantity: 8,
    category_id: gaming_category.id,
    is_active: true,
    weight: 35.0,
    dimensions: "26.8 x 26.8 x 48.4 inches"
  },
  %{
    name: "Smartphone Stand",
    description: "Adjustable smartphone stand for desk use. Compatible with all phone sizes and tablets.",
    price: Decimal.new("19.99"),
    sku: "SS-009",
    stock_quantity: 75,
    category_id: tech_category.id,
    is_active: true,
    weight: 0.6,
    dimensions: "6.3 x 4.3 x 4.3 inches"
  },
  %{
    name: "Web Development Masterclass",
    description: "Complete guide to modern web development with React, Node.js, and databases. Includes practical projects.",
    price: Decimal.new("49.99"),
    sku: "WDM-010",
    stock_quantity: 200,
    category_id: books_category.id,
    is_active: true,
    weight: 1.0,
    dimensions: "9.2 x 7.5 x 1.5 inches"
  }
]

Enum.each(products, fn product_attrs ->
  Repo.insert!(%Product{} |> Product.changeset(product_attrs))
end)

# Create Blog Posts
blog_posts = [
  %{
    title: "Welcome to Phoenix CMS",
    slug: "welcome-to-phoenix-cms",
    content: """
    # Welcome to Phoenix CMS

    This is a modern content management system built with Phoenix LiveView. 
    
    ## Features
    
    - Real-time updates
    - User authentication
    - E-commerce functionality
    - Chat system
    - Virtual desktop environment
    - Quest system
    
    We're excited to have you here!
    """,
    excerpt: "Welcome to our new Phoenix CMS platform with modern features and real-time capabilities.",
    published: true,
    featured: true
  },
  %{
    title: "Getting Started with Phoenix LiveView",
    slug: "getting-started-phoenix-liveview",
    content: """
    # Getting Started with Phoenix LiveView

    Phoenix LiveView enables rich, real-time user experiences with server-rendered HTML.

    ## Key Benefits

    - No need to write JavaScript for interactivity
    - Real-time updates out of the box
    - SEO-friendly server-rendered content
    - Reduced complexity compared to SPA frameworks

    ## Basic Example

    ```elixir
    defmodule MyAppWeb.CounterLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        {:ok, assign(socket, count: 0)}
      end

      def handle_event("increment", _params, socket) do
        {:noreply, assign(socket, count: socket.assigns.count + 1)}
      end

      def render(assigns) do
        ~H\"\"\"
        <div>
          <p>Count: <%= @count %></p>
          <button phx-click="increment">+</button>
        </div>
        \"\"\"
      end
    end
    ```

    This creates a real-time counter without any JavaScript!
    """,
    excerpt: "Learn the basics of Phoenix LiveView and how to create interactive web applications.",
    published: true,
    featured: false
  },
  %{
    title: "Building Real-time Features",
    slug: "building-realtime-features",
    content: """
    # Building Real-time Features

    One of the most powerful aspects of Phoenix is its real-time capabilities through Phoenix PubSub.

    ## Phoenix PubSub

    PubSub allows you to broadcast messages to multiple processes, enabling real-time features like:

    - Live chat
    - Real-time notifications
    - Collaborative editing
    - Live updates

    ## Example: Live Chat

    ```elixir
    # Broadcasting a message
    Phoenix.PubSub.broadcast(MyApp.PubSub, "chat:lobby", {:new_message, message})

    # Subscribing to messages
    Phoenix.PubSub.subscribe(MyApp.PubSub, "chat:lobby")

    # Handling messages in LiveView
    def handle_info({:new_message, message}, socket) do
      {:noreply, assign(socket, messages: [message | socket.assigns.messages])}
    end
    ```

    This enables instant message delivery to all connected users!
    """,
    excerpt: "Discover how to build real-time features using Phoenix PubSub and LiveView.",
    published: true,
    featured: false
  }
]

Enum.each(blog_posts, fn post_attrs ->
  Repo.insert!(%Post{} |> Post.changeset(post_attrs))
end)

# Create Chat Channels
channels = [
  %{
    name: "general",
    description: "General discussion for everyone",
    channel_type: "text"
  },
  %{
    name: "tech-talk",
    description: "Discuss technology and programming",
    channel_type: "text"
  },
  %{
    name: "gaming",
    description: "Gaming discussions and LFG",
    channel_type: "text"
  },
  %{
    name: "random",
    description: "Random conversations and off-topic",
    channel_type: "text"
  }
]

Enum.each(channels, fn channel_attrs ->
  Repo.insert!(%Channel{} |> Channel.changeset(channel_attrs))
end)

IO.puts("✅ Seed data created successfully!")
IO.puts("📦 Created #{length(products)} products")
IO.puts("📝 Created #{length(blog_posts)} blog posts") 
IO.puts("💬 Created #{length(channels)} chat channels")
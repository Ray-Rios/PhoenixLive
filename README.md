# Phoenix CMS - Professional Website Builder

A modern, real-time collaborative CMS built with Phoenix/Elixir, featuring GraphQL API, Redis caching, and live chat functionality.

## Features

- **Professional Starry Landing Page** - Beautiful animated background with smooth transitions
- **User Authentication** - Email-based registration and login system
- **Avatar System** - 100+ customizable avatar shapes and colors
- **Real-time Chat** - Live collaboration with chat bubbles above user avatars
- **WYSIWYG Editor** - Visual page editing with drag-and-drop functionality
- **Template System** - Pre-built templates for service and product businesses
- **GraphQL API** - Modern API with Apollo integration
- **Redis Caching** - Fast content delivery and session management
- **Responsive Design** - Professional look with familiar navigation elements



## Architecture

### Backend Stack
- **Phoenix Framework** - Web framework and LiveView for real-time UI
- **Elixir/Erlang** - Concurrent, fault-tolerant runtime
- **PostgreSQL** - Primary database for user data and content
- **Redis** - Session storage and real-time features
- **GraphQL (Absinthe)** - Modern API layer
- **Session-based Auth** - Secure authentication system

### Frontend Stack
- **Phoenix LiveView** - Server-rendered real-time UI
- **TailwindCSS** - Utility-first styling
- **Alpine.js** - Lightweight JavaScript framework
- **Custom CSS** - Animated backgrounds and avatar shapes

### Key Components

#### Authentication System
- Email/password registration and login
- JWT token-based sessions
- Password validation with security requirements
- Email confirmation workflow (via MailHog in development)

#### Avatar System
- 100+ unique avatar shapes (circles, polygons, custom shapes)
- 50+ color options
- Real-time avatar display in chat
- Persistent avatar selection per user

#### Real-time Features
- Phoenix Presence for user tracking
- Live chat with message bubbles
- Real-time user status updates
- WebSocket-based communication
- Node caching optimized

#### Content Management
- WYSIWYG page editor
- Template-based page creation
- Service business template (5 pages)
- Product business template (5 pages)
- Page publishing workflow

## Configuration

### Environment Variables

#### Development
```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5432/phoenix_app_dev
REDIS_URL=redis://localhost:6379
SECRET_KEY_BASE=your_secret_key_here
```

#### Production
```bash
DATABASE_URL=postgres://user:pass@host:5432/database
REDIS_URL=redis://host:6379
SECRET_KEY_BASE=your_production_secret
SMTP_RELAY=your.smtp.server
SMTP_USERNAME=your_username
SMTP_PASSWORD=your_password
# SSL_KEY_PATH=/path/to/ssl.key
# SSL_CERT_PATH=/path/to/ssl.crt
```

### Production Deployment

#### HTTP/HTTPS Configuration
Uncomment the following in `config/prod.exs` for production:
```elixir
config :phoenix_app, PhoenixAppWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 80],
  https: [
    ip: {0, 0, 0, 0},
    port: 443,
    cipher_suite: :strong,
    keyfile: System.get_env("SSL_KEY_PATH"),
    certfile: System.get_env("SSL_CERT_PATH")
  ]
```

#### Docker Production
```bash
# Build production image
docker build -t phoenix-cms:prod .

# Run with production config
docker run -p 80:80 -p 443:443 \
  -e DATABASE_URL=your_db_url \
  -e REDIS_URL=your_redis_url \
  -e SECRET_KEY_BASE=your_secret \
  phoenix-cms:prod
```

## API Documentation

### GraphQL Endpoints
- **Query Endpoint:** `/api/graphql`
- **GraphiQL Interface:** `/graphiql`

### Key Mutations
```graphql
# User Registration
mutation {
  register(input: {email: "user@example.com", password: "SecurePass123!"}) {
    token
    user { id email }
  }
}

# Create Page
mutation {
  createPage(input: {title: "Home", content: "<h1>Welcome</h1>", templateType: "service"}) {
    id title slug
  }
}
```

### Subscriptions
```graphql
# Chat Messages
subscription {
  messageAdded {
    id content user { email }
  }
}

# User Presence
subscription {
  userPresence {
    userId status user { email avatarShape avatarColor }
  }
}
```

## Templates

### Service Business Template
- Home page with hero section
- About page with team information
- Services page with offerings
- Contact page with form
- Blog page for updates

### Product Business Template
- Product showcase homepage
- Product catalog with categories
- Individual product pages
- Shopping cart integration
- Customer testimonials

## Security Features

- CSRF protection on all forms
- Password strength validation
- SQL injection prevention via Ecto
- XSS protection in templates
- Secure session management
- Rate limiting (configurable)

## Performance Optimizations

- Redis caching for sessions and frequently accessed data
- Database query optimization with Ecto
- Asset minification and compression
- CDN-ready static asset serving
- Connection pooling for database and Redis

## Monitoring & Observability

- Phoenix LiveDashboard at `/dev/dashboard` (development)
- Telemetry metrics collection
- Error tracking and logging
- Performance monitoring hooks

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the GitHub repository
- Check the documentation in the `/docs` folder
- Review the GraphiQL interface for API documentation
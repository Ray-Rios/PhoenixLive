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

## API Documentation

### GraphQL Endpoints
- **Query Endpoint:** `/api/graphql`
- **GraphiQL Interface:** `/graphiql`

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

🎮 UE5 Desktop Game ←→ 🦀 Rust Server (9069) ←→ 🗄️ Database
                              ↕
                    🌐 Phoenix Dashboard (4000) ←→ 📦 Redis


## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the GitHub repository
- Check the documentation in the `/docs` folder
- Review the GraphiQL interface for API documentation
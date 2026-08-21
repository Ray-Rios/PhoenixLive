
# Database Schema Visual Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHOENIX APP - CONSOLIDATED DATABASE SCHEMA                │
│                           (50+ Tables, 100+ Indexes)                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ 1. USER AUTHENTICATION & SECURITY                                         │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────┐         ┌──────────────────┐       ┌──────────────────┐│
│  │    users    │────1:N──│  users_tokens    │       │ login_attempts   ││
│  │  (30 fields)│         │ (session tokens) │       │ (track logins)   ││
│  └──────┬──────┘         └──────────────────┘       └──────────────────┘│
│         │                                                                 │
│         ├──────1:N────┐                                                  │
│         │             │                                                  │
│    ┌────▼─────┐  ┌───▼──────────────┐   ┌───────────────────────┐     │
│    │ device_  │  │  blocked_        │   │ allowed_identifiers   │     │
│    │ finger   │  │  identifiers     │   │ (allowlist)           │     │
│    │ prints   │  │  (blocklist)     │   └───────────────────────┘     │
│    └─────┬────┘  └──────────────────┘                                  │
│          │                                                              │
│          │                                                              │
│    ┌─────▼──────────┐                                                  │
│    │ behavioral_data│                                                  │
│    │ (bot detection)│                                                  │
│    └────────────────┘                                                  │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ 2. CONTENT MANAGEMENT (POSTS & MEDIA)                                    │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────┐                                                         │
│  │    users    │                                                         │
│  └──────┬──────┘                                                         │
│         │                                                                │
│         ├─────────1:N─────────┬──────────1:N──────────┐                │
│         │                     │                        │                │
│    ┌────▼─────┐         ┌─────▼──────┐         ┌─────▼──────┐         │
│    │  posts   │──1:N───│ comments   │         │   pages    │         │
│    │(modern)  │         │            │         │            │         │
│    └────┬─────┘         └────────────┘         └────────────┘         │
│         │                                                               │
│         │ N:M (via post_media)                                         │
│         │                                                               │
│    ┌────▼─────────┐                                                    │
│    │ user_media ⭐│───1:N───┐                                          │
│    │ (images/     │          │                                         │
│    │  videos/     │     ┌────▼────────┐                               │
│    │  audio/3D)   │     │ media_tags  │                               │
│    └──────────────┘     │(organize)   │                               │
│                         └─────────────┘                                │
│                                                                         │
│  WordPress-Style CMS:                                                  │
│  ┌────────────┐      ┌─────────────────┐      ┌──────────────┐       │
│  │ cms_posts  │──1:N─│ cms_post_meta   │      │ cms_comments │       │
│  └──────┬─────┘      └─────────────────┘      └──────┬───────┘       │
│         │ N:M                                         │1:N            │
│         │                                        ┌────▼────────────┐  │
│    ┌────▼──────────────────┐                    │ cms_comment_    │  │
│    │ cms_post_term_        │                    │ meta            │  │
│    │ relationships         │                    └─────────────────┘  │
│    └────┬──────────────────┘                                         │
│         │                                                             │
│    ┌────▼──────┐                                                     │
│    │ cms_terms │───1:N───┐                                           │
│    └────┬──────┘          │                                          │
│         │            ┌────▼──────────┐                               │
│    ┌────▼────────┐  │ cms_term_meta │                               │
│    │ cms_        │  └───────────────┘                                │
│    │ taxonomies  │                                                   │
│    └─────────────┘                                                   │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ 3. E-COMMERCE SYSTEM                                                      │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────┐                                                         │
│  │    users    │                                                         │
│  └──────┬──────┘                                                         │
│         │                                                                │
│         ├─────────1:1─────────┬─────────1:N────────┐                   │
│         │                     │                     │                   │
│    ┌────▼─────┐          ┌────▼────┐          ┌────▼────┐             │
│    │  carts   │───1:N───│ orders  │───1:N───│ order_  │             │
│    └────┬─────┘          └────┬────┘          │ items   │             │
│         │                     │               └────┬────┘             │
│         │1:N                  │1:N                 │N:1               │
│         │                     │                    │                   │
│    ┌────▼─────────┐      ┌────▼────────────┐ ┌───▼────────┐          │
│    │ cart_items   │      │   (same link)   │ │  products  │          │
│    └────┬─────────┘      └─────────────────┘ └──────┬─────┘          │
│         │N:1                                         │N:1             │
│         │                                            │                │
│         └─────────────────────┬────────────────────┘                 │
│                               │                                       │
│                          ┌────▼──────────┐                            │
│                          │  categories   │                            │
│                          └───────────────┘                            │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ 4. CHAT SYSTEM                                                            │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌────────────────┐                                                      │
│  │ chat_channels  │                                                      │
│  └────────┬───────┘                                                      │
│           │1:N                                                           │
│           │                                                              │
│      ┌────▼──────────┐                                                   │
│      │ chat_messages │───1:N───┬──────────────┐                        │
│      └────┬──────────┘          │              │                        │
│           │                     │              │                        │
│           │1:N             ┌────▼─────────┐ ┌──▼──────────────┐        │
│           │                │ chat_message │ │ chat_reactions  │        │
│      ┌────▼────────┐       │ _attachments│ │ (emoji)         │        │
│      │ chat_threads│       └──────────────┘ └─────────────────┘        │
│      └─────────────┘                                                    │
│           │                                                              │
│           └──────► parent_message_id (circular ref)                     │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ 5. FILE MANAGEMENT                                                        │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────┐                                                         │
│  │    users    │                                                         │
│  └──────┬──────┘                                                         │
│         │                                                                │
│         ├─────────1:N─────────┬───────────1:N──────────┐               │
│         │                     │                         │               │
│    ┌────▼──────┐        ┌─────▼────────┐        ┌─────▼────────┐      │
│    │user_files │        │ user_media ⭐│        │ (see content │      │
│    │(legacy)   │        │ (new system) │        │  section)    │      │
│    └───────────┘        └──────────────┘        └──────────────┘      │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ 6. CMS CONFIGURATION                                                      │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│     ┌──────────────┐                                                     │
│     │ cms_options  │  (Site-wide settings/config)                       │
│     └──────────────┘                                                     │
└───────────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════
                            KEY RELATIONSHIPS
═══════════════════════════════════════════════════════════════════════════

1:1   = One-to-One       (e.g., user has one cart)
1:N   = One-to-Many      (e.g., user has many posts)
N:M   = Many-to-Many     (e.g., posts ↔ media via post_media)
N:1   = Many-to-One      (e.g., many posts belong to one user)

═══════════════════════════════════════════════════════════════════════════
                              NEW TABLES ⭐
═══════════════════════════════════════════════════════════════════════════

user_media       - Central media library (images/videos/audio/3D/docs)
media_tags       - Tag media for organization
post_media       - Link posts to media (many-to-many)

login_attempts   - Track login attempts (security)
blocked_identifiers - IP/fingerprint blocklist
device_fingerprints - Device identification
behavioral_data  - Bot detection
allowed_identifiers - Trusted sources allowlist

═══════════════════════════════════════════════════════════════════════════
                           TABLE STATISTICS
═══════════════════════════════════════════════════════════════════════════

Total Tables:      50+
Total Indexes:     100+
Primary Keys:      50+ (all tables)
Foreign Keys:      80+
Unique Constraints: 30+

Largest Tables by Fields:
  1. users (30+ fields)
  2. user_media (15 fields)
  3. cms_posts (18 fields)
  4. products (13 fields)
  5. device_fingerprints (11 fields)

═══════════════════════════════════════════════════════════════════════════
                          INDEXING STRATEGY
═══════════════════════════════════════════════════════════════════════════

✓ All foreign keys indexed
✓ All slugs have unique indexes
✓ Frequently queried fields indexed (is_published, status, etc.)
✓ Composite indexes for common query patterns
✓ GIN indexes for array fields (tags)
✓ Timestamps indexed for sorting (inserted_at, published_at)

═══════════════════════════════════════════════════════════════════════════
                              DATA TYPES
═══════════════════════════════════════════════════════════════════════════

UUID (binary_id)    - Most tables (distributed systems friendly)
SERIAL (integer)    - CMS legacy tables (compatibility)
JSONB (map)         - Flexible metadata storage
TEXT                - Long content (posts, comments, descriptions)
ARRAY               - Tags, backup codes
DECIMAL             - Money (prices, totals)
BOOLEAN             - Flags (is_published, is_admin, etc.)
TIMESTAMPS          - All tables (inserted_at, updated_at)

═══════════════════════════════════════════════════════════════════════════
                          CASCADE BEHAVIORS
═══════════════════════════════════════════════════════════════════════════

ON DELETE CASCADE    - Child records deleted when parent deleted
                      (e.g., delete user → delete their posts)

ON DELETE SET NULL   - Foreign key nullified when parent deleted
                      (e.g., delete admin → set approved_by_id to NULL)

ON DELETE NILIFY ALL - Same as SET NULL for multiple rows

═══════════════════════════════════════════════════════════════════════════
```

**Legend:**
- ⭐ = New tables added in consolidated migration
- 1:1 = One-to-One relationship
- 1:N = One-to-Many relationship  
- N:M = Many-to-Many relationship
- N:1 = Many-to-One relationship

**File:** `20251020094500_full_api_consolidated.exs`  
**Lines:** 1000+  
**Status:** Complete and ready for fresh installs

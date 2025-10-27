# Content Management & Media Upload Strategy

## Current Situation
- Blog posts are stored in database with text content
- No media/asset management system
- No user-specific content folders
- Need WordPress-like content management

## Proposed Solution

### 1. File Storage Structure
```
uploads/
├── users/
│   ├── {user_id}/
│   │   ├── images/
│   │   ├── videos/
│   │   ├── audio/
│   │   ├── 3d_assets/
│   │   └── files/
├── public/
│   ├── images/
│   ├── video/
│   ├── audio/
│   ├── 3d_assets/
│   └── files/
└── temp/
```

### 2. Database Schema for Media

#### Create `user_media` table:
```sql
CREATE TABLE user_media (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  filename VARCHAR(255) NOT NULL,
  original_filename VARCHAR(255) NOT NULL,
  file_type VARCHAR(100) NOT NULL, -- image, video, audio, 3d_model, document
  mime_type VARCHAR(100) NOT NULL,
  file_size BIGINT NOT NULL,
  file_path TEXT NOT NULL, -- relative path from uploads/
  url TEXT NOT NULL, -- public URL to access file
  metadata JSONB, -- {width, height, duration, etc}
  alt_text TEXT,
  caption TEXT,
  usage_context VARCHAR(50), -- blog, avatar, profile, etc
  is_public BOOLEAN DEFAULT false,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_media_user_id ON user_media(user_id);
CREATE INDEX idx_user_media_file_type ON user_media(file_type);
CREATE INDEX idx_user_media_usage_context ON user_media(usage_context);
```

### 3. Implementation Steps

#### Phase 1: Basic Media Upload (Week 1)
1. ✅ Create `UserMedia` schema module
2. ✅ Create media upload LiveView component
3. ✅ Implement file validation (size, type)
4. ✅ Store files in user-specific directories
5. ✅ Generate thumbnails for images
6. ✅ Create media library view

#### Phase 2: Rich Editor Integration (Week 2)
1. ✅ Add image picker to blog editor
2. ✅ Implement drag-and-drop upload
3. ✅ Add image insertion into markdown
4. ✅ Support for video embeds
5. ✅ Add audio player shortcodes

#### Phase 3: Advanced Features (Week 3)
1. ⏳ 3D model viewer integration
2. ⏳ Image editing (crop, resize)
3. ⏳ CDN integration
4. ⏳ Media optimization/compression
5. ⏳ Gallery management

### 4. Usage Examples

#### Upload Image in Blog Editor:
```elixir
# In blog editor, add upload button:
<.live_file_input upload={@uploads.featured_image} />

# Process upload:
def handle_event("save", %{"post" => post_params}, socket) do
  uploaded_files = consume_uploaded_entries(socket, :featured_image, fn %{path: path}, entry ->
    dest = Path.join("uploads/users/#{user_id}/blog/images", entry.client_name)
    File.cp!(path, dest)
    {:ok, "/uploads/users/#{user_id}/blog/images/#{entry.client_name}"}
  end)
  
  post_params = Map.put(post_params, "featured_image", List.first(uploaded_files))
  # ... save post
end
```

#### Insert Image in Markdown:
```markdown
![Alt text](/uploads/users/{user_id}/blog/images/my-image.jpg)
```

### 5. Security Considerations
- ✅ Validate file types (whitelist)
- ✅ Limit file sizes
- ✅ Scan for malware
- ✅ User-isolated directories
- ✅ Signed URLs for private content
- ✅ Rate limiting on uploads

### 6. WordPress-Like Features

#### Media Library:
- Grid view of all user media
- Filter by type (images, videos, etc)
- Search by filename/tags
- Bulk actions (delete, move)
- Usage tracking (which posts use this media)

#### Rich Editor:
- "Add Media" button
- Insert from media library
- Upload new files inline
- Image alignment options
- Caption support
- Alt text for accessibility

### 7. Quick Start Implementation

Run migration:
```bash
mix ecto.gen.migration create_user_media
```

Then implement the schema and context in next iteration.

### 8. File Serving Strategy

**Development:**
- Serve from local `uploads/` via Phoenix static plug

**Production:**
- Option 1: Serve via Phoenix (simple, less performant)
- Option 2: Use Nginx/Apache (better performance)
- Option 3: Use CDN (S3, CloudFlare, etc) - Best for scale

### 9. Immediate Next Steps

1. Create migration for `user_media` table
2. Create `UserMedia` schema
3. Add upload LiveComponent to blog editor
4. Create media library page
5. Update blog post to support featured images
6. Add image insertion to markdown editor

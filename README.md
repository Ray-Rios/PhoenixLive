📋 Production Ready Features
Professional HTML email templates configured
Rate limiting and security measures active
Failed login attempt tracking
Account locking after multiple failed attempts
Email or username login flexibility
Complete API coverage for external applications

🔐 API Endpoints Tested & Working
✅ POST /api/auth/register - User registration with email verification
✅ POST /api/auth/verify-code - Email verification with 6-digit codes
✅ POST /api/auth/login - Login with email/username support
✅ POST /api/auth/logout - Session cleanup and JWT invalidation


## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Support
For support and questions:
- Create an issue in the GitHub repository
- Check the Handy_Command_Samples.md for inspiration

## Handling Build Warnings

Recent build produced warnings:

NPM deprecations: inflight (transitive), glob@7.x, rimraf@3.x, eslint@8.57.x.
Elixir warnings: duplicate/unreachable `handle_event/3` clauses in `user_management_live.ex` and scattered clauses in `auth_live.ex`.

Remediations applied:
1. Removed duplicate `confirm_delete`, `delete_user`, `cancel_delete` clauses in `user_management_live.ex`.
2. Grouped CAPTCHA `handle_event` clauses in `auth_live.ex`.

Proposed dependency update path (safe increments):
1. TailwindCSS -> ^3.4.x
2. ESLint -> latest 8.x (keep @typescript-eslint at 6.x) then optionally ESLint 9 with @typescript-eslint 7.x after validation.
3. TypeScript -> keep 5.x until all eslint plugins confirmed compatible.

Rationale: Upgrading ESLint first removes most deprecated transient packages. Jumping directly to major versions without aligning plugin versions can break CI.

## Assets & Local Builds (Important)

Frontend assets are built inside containers or in CI to ensure reproducible builds and to avoid environment-specific issues (especially on Windows).

- `mix assets.setup`, `mix assets.build`, and the lint aliases will now refuse to run npm on your host unless you opt in. This prevents accidental -- and often destructive -- host npm installs. If you need to build assets locally, run the Docker command below.

Local Docker-based build example (recommended):

```bash
# Use the repo's dev-assets helper which wraps the Docker invocation:
./scripts/dev-assets.sh build
```

If you need to run `npm` on your host (not recommended), you can still do so manually, but prefer the helper above.


Verification commands:
```
mix compile
./scripts/dev-assets.sh run type-check && ./scripts/dev-assets.sh build
```

To trace deprecated packages:
```
cd assets
npm ls glob rimraf inflight eslint
```

Track future policy: treat new compiler warnings as CI failures; address or document intentional exceptions.

## Redis-backed PubSub (cross-pod real-time)

To enable Redis-backed pubsub bridging for cross-pod real-time event delivery, set these environment variables in your cluster (for example in a k8s ConfigMap):

	ENABLE_REDIS=true
	REDIS_URL=redis://redis:6379/0

This project includes a small Redis PubSub bridge that subscribes to channel patterns (e.g. "channel:*", "presence:channel:*", "chat:channels") and forwards Redis messages into the local Phoenix.PubSub. When Redis is enabled the application will also publish messages into Redis so other pods receive them.

Note: For higher durability/compatibility you can switch Phoenix.PubSub to a Redis adapter (install a compatible adapter library) and configure it in runtime.exs — the repo includes conditional helpers to enable bridging when Redis is present.
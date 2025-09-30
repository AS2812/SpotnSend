# SpotnSend Admin Dashboard

Admin web console for the SpotnSend schema. The React (Vite) app talks to Supabase on the client for reads and uses a small Express service (with the Supabase service role key) for privileged writes.

## Requirements
- Node.js 18+
- Supabase project with PostGIS enabled
- Buckets: `report-media`, `identity-docs`, `public-assets`
- Sentry DSNs (optional, but recommended)

## Database bootstrap
1. Install extensions, views, policies, RPCs:
   ```sh
   psql < migration.sql
   ```
2. Seed core lookup tables:
   ```sh
   psql < seeds.sql
   ```
3. Regenerate typed client helpers when the schema changes:
   ```sh
   npx supabase gen types typescript \
     --project-id <project-id> --schema public \
     > src/types/supabase.ts
   ```

## Environment variables
Copy `.env.local.example` to `.env.local` and fill in real values. Key entries:
- `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` – browser client
- `SUPABASE_SERVICE_ROLE_KEY` – **server only**; never expose to the browser
- `VITE_API_BASE` – base URL that the browser uses for privileged API calls (defaults to `http://localhost:4000` during local dev)
- `MAPTILER_KEY` – map tiles + geolocation support
- `SENTRY_DSN` / `SENTRY_DSN_SERVER` – front-end and Express crash reporting
- `VITE_PLAUSIBLE_DOMAIN` or `VITE_GA_MEASUREMENT_ID` – optional analytics
- `VITE_BYPASS_AUTH` – set to `1` only in automated tests to skip Supabase auth

> Geolocation requires HTTPS in production. The map component renders a warning overlay when the app is served over plain HTTP on a non-localhost host.

## Running locally
1. Install dependencies:
   ```sh
   npm install
   ```
2. Start the privileged API (loads `.env.local`):
   ```sh
   npm run server
   ```
3. In another shell start Vite:
   ```sh
   npm run dev
   ```
   By default the app expects the API at `http://localhost:4000`. Change `VITE_API_BASE` if you proxy through a different origin.

### Monitoring & analytics
- Sentry initialises automatically when `VITE_SENTRY_DSN` (client) or `SENTRY_DSN_SERVER` (server) is present.
- Plausible: set `VITE_PLAUSIBLE_DOMAIN` (and an optional `VITE_PLAUSIBLE_SCRIPT`).
- GA4: set `VITE_GA_MEASUREMENT_ID`.

## Cypress smoke tests
The suite expects the dashboard to auto-authenticate via `VITE_BYPASS_AUTH=1`.

1. In one terminal start Vite with the bypass flag:
   ```sh
   VITE_BYPASS_AUTH=1 npm run dev
   ```
2. In another terminal run the tests (they stub network calls):
   ```sh
   npm run test:e2e
   ```
   Use `npm run cy:open` for interactive debugging.

The smoke set covers:
- Map screen rendering and legend
- Realtime event bridge updating the incidents table
- Assign action issuing a privileged `/api/reports/:id` PATCH

## Deployment (Vercel example)
A `vercel.json` is provided:
- Static build of the Vite app (`npm run build` -> `dist`)
- Serverless function wrapping `server/index.js`
- `/api/*` routes forwarded to the Express handler

Set the following environment variables in Vercel (Preview + Production):
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `VITE_API_BASE` (usually the deployed serverless endpoint)
- `MAPTILER_KEY`
- Monitoring/analytics keys as needed

Redeploy when the SQL layer changes or when regenerating Supabase types.

## Notes
- All `POST /api/*` endpoints require a Supabase admin session token; the middleware verifies the JWT and role via `users.role = 'admin'`.
- Privileged writes attempt to log into `audit_events`. If the table is absent the API degrades gracefully.
- `VITE_BYPASS_AUTH` and `VITE_BYPASS_AUTH=1` must never be enabled in real deployments.

## Project structure
- `src/` — React app, pages, components, providers, and MapLibre integration
- `server/` — Express service that performs privileged actions using `SUPABASE_SERVICE_ROLE_KEY`
- `db/` — SQL migrations, row‑level security, and storage policies
- `cypress/` — Smoke tests (headless and interactive)
- `docs/` — Additional product/feature notes

## API reference (Express)
Browser calls go through `src/utils/api.ts` to the Express service. Main endpoints:
- `POST /api/reports/:id` — update report fields (status, priority, TTL override)
- `POST /api/reports/:id/delete` — soft/hard delete a report (per policy)
- `POST /api/reports/:id/note` — append an internal note
- `POST /api/dispatch` — create a dispatch to an external authority
- `POST /api/dispatch/:id/status` — update dispatch status
- `POST /api/users/:id/suspend` — suspend a user
- `POST /api/users/:id/activate` — re‑activate a user
- `POST /api/users` — create a user
- `PATCH /api/users/:id` — update a user
- `DELETE /api/users/:id` — delete a user

All endpoints require a valid Supabase JWT in `Authorization: Bearer <token>`; the server validates role and scopes before performing writes.

## Example environment (.env.local)
Do not paste real secrets into the repo. Create `.env.local` with placeholders like:
```
VITE_SUPABASE_URL=https://<project-id>.supabase.co
VITE_SUPABASE_ANON_KEY=anon-key
SUPABASE_SERVICE_ROLE_KEY=service-role-key
VITE_API_BASE=http://localhost:4000
MAPTILER_KEY=<your-maptiler-key>
```

## Production build
- Build: `npm run build` → outputs `dist/`
- Preview locally: `npm run preview`
- Deploy (example Vercel): configure env vars in the project settings, ensure HTTPS and correct `VITE_API_BASE`.

## Troubleshooting
- “Map requires HTTPS”: serve over HTTPS or develop on `localhost`.
- 401 from `/api/*`: confirm Supabase session exists and JWT is forwarded.
- 403 from `/api/*`: the user is not an admin; check `users.role` in DB.
- SQL errors: re‑apply `migration.sql` and `seeds.sql`, and confirm storage policies.
- Cypress bypass not working: ensure `VITE_BYPASS_AUTH=1` is set for both the dev server and Cypress process.

## Security model
- The React app uses Supabase RLS for all reads.
- The Express layer uses `SUPABASE_SERVICE_ROLE_KEY` for privileged writes and logs actions into `audit_events` when available.
- Never expose the service role key to the browser or client bundles.


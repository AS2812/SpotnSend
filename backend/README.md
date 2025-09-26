# Civic Watch Backend (PostgreSQL + Express)

This service exposes the REST API, WebSocket notifications, and background helpers required by the Flutter clients.

## Prerequisites

- Node.js 18+
- PostgreSQL 14+ with the extensions used in `database.sql` (`uuid-ossp`, `citext`, `postgis`, `pgcrypto`)
- A configured `.env` file (see `.env.example`)

## Initial setup

1. Apply the PostgreSQL schema:
   ```bash
   psql -f ../database.sql
   ```
2. Install Node dependencies:
   ```bash
   cd backend
   npm install
   ```
3. Copy and adjust environment variables:
   ```bash
   cp .env.example .env
   # edit .env with correct DATABASE_URL, JWT secrets, etc.
   ```

### Verify Supabase/PostGIS functions

Run the helper once you have a working connection string to make sure all required extensions and SQL functions are present (PostGIS, custom RPCs, triggers, etc.):

```bash
npm run verify:functions
```

The script inspects `pg_extension` and `pg_proc` for the full function list used by the backend and Flutter client (including `reports_nearby`, `create_report_simple`, PostGIS spatial operators, notification helpers, etc.). Missing items will be logged and the process exits with a non-zero status so you can surface issues in CI.

## Running locally

```bash
npm run dev
```

This starts the API on `http://localhost:8080` and enables hot reload through `nodemon`.

## Project structure

```
backend/
  src/
    config/           # environment + database helpers
    controllers/      # request handling logic
    middleware/       # auth, validation, rate limiters, uploads, errors
    routes/           # REST partitions (auth, users, reports, notifications, admin)
    services/         # business logic and database queries
    sockets/          # Socket.IO setup and emit helpers
    validators/       # Zod schemas shared by routes
    server.js         # Express bootstrap
```

## Key endpoints

All endpoints are prefixed with `/api`.

- `POST /auth/signup/step1` ? create account + send OTP
- `POST /auth/signup/step2` ? attach ID data
- `POST /auth/signup/step3` ? selfie upload + verification request
- `POST /auth/login` / `POST /auth/refresh` / `POST /auth/logout`
- `GET /users/profile` / `PATCH /users/profile`
- `GET /users/settings` / `PUT /users/settings`
- `POST /reports` ? submit incident (requires verified account)
- `GET /reports/nearby` ? map/list data (supports radius + category filters)
- `POST /reports/:id/feedback` and `POST /reports/:id/flag`
- `GET /notifications` / `POST /notifications/mark`
- Admin: `GET /admin/users`, `PATCH /admin/users/:id/status`, `GET /admin/verifications/pending`, `PATCH /admin/verifications/:id`

See the route files under `src/routes` for the full list and query/JSON payloads.

## Flutter integration notes

- Use the `/auth/signup/*` routes to drive the three-step onboarding wizard. Persist the `userId` returned from Step 1 for subsequent steps.
- Store `accessToken` + `refreshToken` from `/auth/login` in secure storage. Add the header `Authorization: Bearer <token>` to all authenticated requests.
- Use `/reports/nearby` for the Map and List tabs. Pass `radius`, `categories`, `subcategories`, and `statuses` query parameters to match the user?s filters.
- After submitting a report, listen on the WebSocket channel `report:update` to refresh UI cards in real-time.
- Notifications tab hits `/notifications` (list) and `/notifications/mark` (mark read). The server also emits `notification` events over WebSocket for live updates.
- Reporting locks are enforced in the database via triggers; the API will return `403` if an unverified user attempts to submit a report.

## Background tasks / integrations

- Replace the placeholder SMS + email providers using the keys defined in `.env` to send OTP codes and authority alerts.
- The `uploads` directory is provided for local development. In production swap `multer`?s storage with S3, Azure Blob Storage, or any managed object store.
- Socket.IO rooms are used for `user:{id}` (notifications) and `city:{name}` (report updates). Join rooms from Flutter using the same naming convention.

## Linting

```bash
npm run lint
```

---

For deployment, consider a process manager such as PM2 or containerize the service with Docker, ensuring the environment variables and PostgreSQL network access are configured securely.

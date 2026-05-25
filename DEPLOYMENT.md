# Deployment Guide

## Recommended Setup

- Backend : Render web service
- PostgreSQL: Neon free Postgres
- File uploads: Cloudinary free
- Android app: release APK/AAB built with a public API URL

## Why This Setup

- Your backend is already Docker-ready.
- Render gives the API a public HTTPS URL.
- Your app already supports runtime API configuration via `--dart-define=API_BASE_URL=...`.
- Neon provides a free Postgres database.
- Cloudinary avoids Render's ephemeral filesystem limitation on free instances.

## 1. Prepare Secrets

Before deploying, rotate any secrets that were previously used in local `.env` files:

- database password
- JWT secret
- Brevo API key
- Gmail app password if you keep SMTP fallback
- Cloudinary API credentials

Use [backend/.env.example](/home/mordern-developer/Desktop/student-job-platform/backend/.env.example) as the production template.

## 2. Push The Repo

Push this repository to GitHub or GitLab.

## 3. Create Neon Database

Create a free Neon Postgres database and copy its connection string.

Set SSL mode in the connection string if Neon doesn't add it automatically:

`?sslmode=require`

## 4. Create Cloudinary Storage

Create a free Cloudinary account and collect:

- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

## 5. Create Render Web Service

Render can read [render.yaml](/home/mordern-developer/Desktop/student-job-platform/render.yaml) from the repo root and create a free Docker web service for the API.

During setup, provide:

- `DATABASE_URL` from Neon
- `PUBLIC_API_URL`
- `RESET_PASSWORD_BASE_URL`
- `BREVO_API_KEY`
- `RESEND_API_KEY`
- `RESEND_FROM`
- `RESEND_REPLY_TO`
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`
- `EMAIL_FROM`
- `BOOTSTRAP_ADMIN_EMAILS`
- `BOOTSTRAP_ADMIN_PASSWORD`
- `ROLE_SYNC_OVERRIDES`

Set both URL variables to your final public backend URL, for example:

`https://student-job-platform-api.onrender.com`

To make Render match your localhost roles for important accounts:

- Set `BOOTSTRAP_ADMIN_EMAILS` to one or more emails separated by commas.
- Set `BOOTSTRAP_ADMIN_PASSWORD` to the password that those admin accounts should use.
- Optionally set `ROLE_SYNC_OVERRIDES` like `amostangawizi800@gmail.com:admin,user@example.com:student`.

On every backend restart, the API will create missing bootstrap admins and promote existing matching users to the configured roles.

For password reset emails that work from anywhere:

- Set `PUBLIC_API_URL` and `RESET_PASSWORD_BASE_URL` to the same public HTTPS backend URL.
- Configure either `RESEND_API_KEY` or `BREVO_API_KEY` for delivery.
- Do not rely on Gmail SMTP alone on Render free services.

## 6. Verify Backend

After deploy, test:

- `GET /health`
- login
- forgot password email
- file uploads
- uploaded file URLs

## 7. Build The Mobile App For Production

Build the Android app with the hosted API URL:

```bash
cd student_app
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.onrender.com
```

Or for Play Store:

```bash
cd student_app
flutter build appbundle --release --dart-define=API_BASE_URL=https://your-api.onrender.com
```

## 8. Build The Web App For iPhone And Browser Users

Build the Flutter web bundle with the same public HTTPS API URL:

```bash
cd student_app
flutter build web --release --dart-define=API_BASE_URL=https://your-api.onrender.com
```

The generated static site will be in:

`student_app/build/web`

Upload that folder to any static host such as Netlify, Vercel, Cloudflare Pages, or Firebase Hosting.

Important:

- Do not use `http://localhost:5000` for production web builds.
- iPhone users must open the hosted web URL over HTTPS.
- The app now defaults web builds to the hosted Render API unless you override `API_BASE_URL`.

## 9. Important Production Notes

- Do not keep production secrets in Git.
- The current local fallback IP in the Flutter app is for development only.
- Password reset links must use the public HTTPS API URL in production.
- If `PUBLIC_API_URL` and `RESET_PASSWORD_BASE_URL` are missing, the backend now falls back to the incoming public request host when building reset links.
- Render free services sleep on idle and wake on the next request.
- Render free services cannot use SMTP ports `25`, `465`, or `587`, so API mail providers such as Brevo are recommended.
- In Brevo, verify the sender email you place in `EMAIL_FROM`, otherwise sends can be rejected.
- In Resend, verify the sending domain or sender address used in `RESEND_FROM`, otherwise password reset emails may not reach inboxes.

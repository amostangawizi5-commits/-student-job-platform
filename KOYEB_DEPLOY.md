# Koyeb Deployment Guide

This project can be deployed with:

- `Koyeb` for the Node.js backend
- `Supabase` for PostgreSQL
- direct APK distribution for the Flutter app

## 1. Prepare the backend repository

The backend folder is already prepared for Koyeb:

- `backend/Dockerfile`
- `backend/.dockerignore`
- `backend/.env.example`

## 2. Create a PostgreSQL database

Recommended free option: Supabase.

After creating the database, collect:

- `DATABASE_URL`
- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`

If your provider requires SSL, set:

- `DB_SSL=true`

## 3. Create a Koyeb web service

1. Push the project to GitHub.
2. In Koyeb, create a new `Web Service`.
3. Connect your GitHub repository.
4. Use the `backend` directory as the app root.
5. Deploy using the included `backend/Dockerfile`.

## 4. Configure environment variables in Koyeb

Minimum required variables:

- `PORT=8000`
- `DATABASE_URL=...`
- `DB_SSL=true`
- `JWT_SECRET=...`
- `JWT_EXPIRES_IN=7d`
- `PUBLIC_API_URL=https://your-service-name.koyeb.app`
- `RESET_PASSWORD_BASE_URL=https://your-service-name.koyeb.app`
- `PASSWORD_RESET_TOKEN_TTL_MINUTES=60`

Optional email variables:

- `RESEND_API_KEY`
- `RESEND_FROM`
- `RESEND_REPLY_TO`
- `EMAIL_HOST`
- `EMAIL_PORT`
- `EMAIL_USER`
- `EMAIL_PASSWORD`
- `EMAIL_FROM`

## 5. Update the Flutter app to use the Koyeb URL

During testing:

```bash
flutter run --dart-define=API_BASE_URL=https://your-service-name.koyeb.app
```

For release APK:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-service-name.koyeb.app
```

## 6. Important limitation

The backend currently stores uploaded resumes and logos on local disk:

- `backend/uploads/resumes`
- `backend/uploads/logos`

This works, but on Koyeb local files are not reliable long-term after redeploys or restarts.

For production, move uploads to cloud storage later.

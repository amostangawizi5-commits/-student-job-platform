# Koyeb + Vercel Deployment Guide

This is the lowest-cost path for this project:

- Backend API: `Koyeb`
- Database: `Neon Postgres`
- File storage: `Cloudinary`
- Web frontend: `Vercel`

## Order

1. Create the database
2. Create Cloudinary credentials
3. Deploy the backend on Koyeb
4. Verify the backend
5. Deploy the Flutter web frontend on Vercel

## 1. Create a Neon database

Create a free Neon project and copy the Postgres connection string.

Use a connection string like:

`postgresql://USER:PASSWORD@HOST/DBNAME?sslmode=require`

Required backend variable:

- `DATABASE_URL`

## 2. Create a Cloudinary account

Create a free Cloudinary account and collect:

- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

This project can fall back to local disk, but cloud storage is strongly recommended for Koyeb deployments.

## 3. Deploy the backend on Koyeb

1. Push this repository to GitHub.
2. In Koyeb, create a new `Web Service`.
3. Connect the GitHub repository.
4. Set the root directory to `backend`.
5. Use the existing `backend/Dockerfile`.

## 4. Backend environment variables

Set these in Koyeb:

- `NODE_ENV=production`
- `PORT=8000`
- `DATABASE_URL=...`
- `JWT_SECRET=...`
- `JWT_EXPIRES_IN=7d`
- `PUBLIC_API_URL=https://your-service-name.koyeb.app`
- `RESET_PASSWORD_BASE_URL=https://your-service-name.koyeb.app`
- `PASSWORD_RESET_TOKEN_TTL_MINUTES=60`
- `CLOUDINARY_CLOUD_NAME=...`
- `CLOUDINARY_API_KEY=...`
- `CLOUDINARY_API_SECRET=...`

Optional but recommended:

- `RESEND_API_KEY=...`
- `RESEND_FROM=...`
- `RESEND_REPLY_TO=...`
- `EMAIL_FROM=...`
- `ALLOWED_ORIGINS=https://your-vercel-site.vercel.app`

Notes:

- If your database URL already includes `sslmode=require`, you do not need separate DB host variables.
- Set `PUBLIC_API_URL` and `RESET_PASSWORD_BASE_URL` to the same Koyeb URL.

## 5. Verify the backend

After deploy, test:

- `GET /health`
- login
- forgot password
- resume upload

Expected health URL:

`https://your-service-name.koyeb.app/health`

## 6. Deploy Flutter web on Vercel

Create a separate Vercel project pointing to the `student_app` directory.

Use:

- Root Directory: `student_app`
- Build Command: `flutter build web --release --dart-define=API_BASE_URL=https://your-service-name.koyeb.app`
- Output Directory: `build/web`

If Vercel does not have Flutter installed in your build environment, build locally first:

```bash
cd student_app
flutter build web --release --dart-define=API_BASE_URL=https://your-service-name.koyeb.app
```

Then deploy the generated `student_app/build/web` folder to Vercel as a static site.

## 7. Final check

Once Vercel gives you a public site URL:

1. Add that frontend URL to `ALLOWED_ORIGINS` in Koyeb.
2. Redeploy the backend if needed.
3. Test login and uploads from the public frontend.

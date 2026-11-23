# Run locally

## 1. Start the local PostgreSQL service

Install and start PostgreSQL directly on Ubuntu:

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable --now postgresql
```

The backend uses the default local PostgreSQL port `127.0.0.1:5432`.

## 2. Configure and start the API

```bash
cp backend/.env.local.example backend/.env
cd backend
npm install
npm start
```

The API will be available at `http://localhost:5000`. Database tables are created automatically on the first start.

## 3. Start Flutter locally

For Chrome or a desktop target:

```bash
cd student_app
flutter pub get
flutter run -d chrome
```

The app now defaults to `http://localhost:5000` for web and desktop builds. For an Android emulator, use:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

For a physical Android phone, replace the URL with the computer's LAN IP and run the backend on the same network:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_IP:5000
```

Docker is optional; it is not required for this local setup.

## Use the online database from this computer

If the hosted database is public (for example Neon or Supabase), copy its
private `DATABASE_URL` from the hosting provider's environment variables into
`backend/.env`:

```env
DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/DATABASE?sslmode=require
```

Do not commit this value or share it publicly. Test the connection before
starting the API:

```bash
set -a
source backend/.env
set +a
psql "$DATABASE_URL" -c "select current_database(), now();"
```

Then run `cd backend && npm start`. The API will use the online database while
the Flutter app still connects to the local API at `http://localhost:5000`.

## Web portal routes

The web portal uses role-specific paths:

- `/training` — student portal
- `/training-company` — organization/company portal
- `/university` — university portal
- `/admin` — administrator portal

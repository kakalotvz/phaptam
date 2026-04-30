# Phap Tam

Monorepo cho ung dung Phat giao:

- `mobile/`: Flutter Android-first app.
- `backend/`: NestJS API, Prisma, PostgreSQL, Redis, BullMQ, Cloudflare R2.
- `admin/`: React/Vite admin dashboard.
- `docs/ARCHITECTURE.md`: ghi chu kien truc va cac viec can lam tiep de len production.
- `docs/R2_SETUP.md`: huong dan cau hinh Cloudflare R2.

## Mobile

```bash
cd mobile
flutter pub get
flutter run
flutter build apk --debug
```

APK debug sau khi build nam tai:

```text
mobile/build/app/outputs/flutter-apk/app-debug.apk
```

## Backend

```bash
cd backend
copy .env.example .env
docker compose up -d
npm install
npx prisma migrate dev
npm run dev
```

API chay voi prefix `/api`, vi du:

- `GET /api/audio`
- `GET /api/categories/audio`
- `POST /api/upload/presigned-url`
- `POST /api/auth/register`
- `POST /api/admin/audio`

## Admin

```bash
cd admin
npm install
npm run dev
```

Set API endpoint:

```bash
cp .env.example .env
```

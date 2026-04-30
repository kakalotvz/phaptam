# Phap Tam Architecture

## Apps

- `mobile`: Flutter Android-first app using Riverpod, go_router, just_audio-ready player boundary, video-player-ready content screens.
- `backend`: NestJS API with PostgreSQL, Prisma, Cloudflare R2, Redis and BullMQ.

## Backend Flow

1. Admin asks `POST /api/upload/presigned-url`.
2. Client uploads media directly to Cloudflare R2.
3. Admin creates `Audio`, `Video`, `Banner` or `Quote` with the public media URL.
4. Image optimization should run before persisting image URLs in production. The worker skeleton is in `src/jobs/image.processor.ts`.
5. RSS fetch jobs normalize articles into `NewsItem`.

## Next Production Tasks

- Replace mock user id in `UserController` with JWT guard and `request.user.sub`.
- Implement admin role guard for all `/api/admin/*` endpoints.
- Finish RSS worker and image optimizer with Sharp + R2 upload.
- Add Flutter repositories that call the REST API instead of mock content.
- Add integration tests for playlist order, favorites uniqueness and audio progress resume.

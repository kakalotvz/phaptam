# Cấu hình Cloudflare R2 cho Pháp Tâm

Backend dùng Cloudflare R2 để tạo presigned URL. Admin upload file trực tiếp lên R2, sau đó lưu `publicUrl` vào Audio, Video, Banner hoặc Quote.

## 1. Tạo bucket

Vào Cloudflare Dashboard -> R2 Object Storage -> Create bucket.

Gợi ý tên bucket:

```text
phaptam-media
```

## 2. Tạo S3 API token

Vào R2 Object Storage -> Account Details -> API Tokens -> Create token.

Chọn quyền:

```text
Object Read & Write
```

Scope token vào bucket `phaptam-media`.

Sau khi tạo, lưu lại:

```text
Access Key ID
Secret Access Key
Account ID
```

Secret chỉ hiện một lần.

## 3. Bật public URL cho media

Nếu chưa có domain riêng cho CDN, vào bucket -> Settings -> Public Development URL -> Enable.

Lấy Public Bucket URL, ví dụ:

```text
https://pub-xxxxx.r2.dev
```

Giá trị này dùng cho:

```env
R2_PUBLIC_BASE_URL="https://pub-xxxxx.r2.dev"
```

Khi có domain thật, nên dùng Custom Domain thay cho `r2.dev`.

## 4. Cấu hình CORS cho upload từ admin

Trong bucket -> Settings -> CORS policy, thêm policy cho admin:

il

Nếu chạy admin local, thêm:

```text
http://localhost:5173
```

## 5. Điền `.env` trên VPS

```bash
cd /home/phaptam/apps/phaptam/backend
nano .env
```

Điền:

```env
R2_ACCOUNT_ID="account_id_cloudflare"
R2_ACCESS_KEY_ID="access_key_id"
R2_SECRET_ACCESS_KEY="secret_access_key"
R2_BUCKET="phaptam-media"
R2_PUBLIC_BASE_URL="https://pub-xxxxx.r2.dev"
```

Restart backend:

```bash
docker compose -f docker-compose.prod.yml --env-file .env up -d
docker compose -f docker-compose.prod.yml --env-file .env logs --tail=80 api
```

## 6. Kiểm tra presigned upload

```bash
curl -X POST http://127.0.0.1:13010/api/upload/presigned-url \
  -H "Content-Type: application/json" \
  -d '{"kind":"images/audio","contentType":"image/webp"}'
```

Nếu trả về `uploadUrl` và `publicUrl`, backend đã kết nối R2.

Admin hiện upload media mới theo cây thư mục R2:

- Audio kinh/pháp âm -> `/audio/library/{uuid}.mp3`
- Audio thiền/âm nền -> `/audio/meditation/{uuid}.mp3`
- Video pháp thoại -> `/video/dharma/{uuid}.mp4`
- Ảnh audio -> `/images/audio/{uuid}.webp`
- Ảnh video -> `/images/video/{uuid}.webp`
- Ảnh thiền -> `/images/meditation/{uuid}.webp`
- Ảnh bản kinh -> `/images/scripture/{uuid}.webp`
- Ảnh tin tức -> `/images/news/{uuid}.webp`
- Banner -> `/images/banner/{uuid}.webp`
- Quote -> `/images/quote/{uuid}.webp`

Backend vẫn nhận `audio` và `video` để không làm hỏng dữ liệu/công cụ cũ, nhưng admin sẽ dùng các nhánh chức năng ở trên cho tệp mới.

Ảnh được chuyển sang WebP trong trình duyệt trước khi upload.

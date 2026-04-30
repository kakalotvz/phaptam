# Ubuntu VPS Deploy Checklist

Huong dan nay gia dinh ban da login bang user `phaptam`.

## 1. Kiem tra truoc khi cai

```bash
whoami
pwd
lsb_release -a
uname -a
free -h
df -h
ss -tulpn
systemctl --type=service --state=running
docker --version || true
docker compose version || true
node --version || true
npm --version || true
nginx -v || true
sudo ufw status verbose || true
```

Neu VPS dang co nhieu app, chon port backend chua dung. Goi y dung `13010` va chi bind local `127.0.0.1`.

Kiem tra port cu the:

```bash
ss -tulpn | grep -E ':(80|443|13010|5432|6379)\b' || true
```

## 2. Cai package nen

```bash
sudo apt update
sudo apt install -y ca-certificates curl git nginx
```

Neu chua co Docker:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker phaptam
newgrp docker
```

## 3. Dua source len VPS

Dat source o:

```bash
/home/phaptam/apps/phaptam
```

Vi du:

```bash
mkdir -p /home/phaptam/apps
cd /home/phaptam/apps
git clone <REPO_URL> phaptam
cd phaptam/backend
```

Khong commit `node_modules`, `dist`, `.env`.

## 4. Tao env production

```bash
cp .env.example .env
nano .env
```

Gia tri can sua:

```env
PORT=13010
ADMIN_PORT=13011
ADMIN_API_BASE_URL=http://208.87.132.135:8001/api
POSTGRES_PASSWORD=doi-mat-khau-that-dai
JWT_SECRET=doi-jwt-secret-that-dai
R2_ACCOUNT_ID=...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET=...
R2_PUBLIC_BASE_URL=https://cdn.tenmiencuaban.com
```

Trong Docker production, `DATABASE_URL` va `REDIS_URL` se duoc override theo service noi bo.

## 5. Chay backend

```bash
docker compose -f docker-compose.prod.yml --env-file .env up -d
docker compose -f docker-compose.prod.yml logs -f api
```

Kiem tra local:

```bash
curl http://127.0.0.1:13010/api/categories/audio
```

Admin dashboard chay noi bo tai:

```bash
curl -I http://127.0.0.1:13011
```

## 6. Cau hinh Nginx

Tao file:

```bash
sudo nano /etc/nginx/sites-available/phaptam-api
```

Noi dung:

```nginx
server {
    listen 80;
    server_name api.tenmiencuaban.com;

    client_max_body_size 20m;

    location / {
        proxy_pass http://127.0.0.1:13010;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Bat site:

```bash
sudo ln -s /etc/nginx/sites-available/phaptam-api /etc/nginx/sites-enabled/phaptam-api
sudo nginx -t
sudo systemctl reload nginx
```

Neu dung IP va port rieng cho admin dashboard, tao them file:

```bash
sudo nano /etc/nginx/sites-available/phaptam-admin
```

Noi dung:

```nginx
server {
    listen 8002;
    server_name _;

    client_max_body_size 20m;

    location /api/ {
        proxy_pass http://127.0.0.1:13010/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://127.0.0.1:13011;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Bat site:

```bash
sudo ln -s /etc/nginx/sites-available/phaptam-admin /etc/nginx/sites-enabled/phaptam-admin
sudo nginx -t
sudo systemctl reload nginx
```

Mo firewall neu chua co:

```bash
sudo ufw allow 8002/tcp
```

Admin se mo tai:

```text
http://IP_VPS:8002
```

## 7. HTTPS

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.tenmiencuaban.com
```

## 8. Lenh van hanh

```bash
cd /home/phaptam/apps/phaptam/backend
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f api
docker compose -f docker-compose.prod.yml restart api
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d --build
```

## 9. Luu y admin

Admin dashboard nam trong `admin/`. Neu dung IP thay vi domain, nen proxy ra port rieng, vi du Nginx `listen 8002` proxy den `127.0.0.1:13011`.

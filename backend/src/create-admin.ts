import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { PrismaService } from './prisma/prisma.service';
import * as bcrypt from 'bcryptjs';

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const prisma = app.get(PrismaService);

  const email = 'leminhkhoa25794@gmail.com';
  const username = 'admin';
  const password = 'Minhkho@94';

  const existing = await prisma.user.findFirst({ where: { email } });
  if (existing) {
    await prisma.user.update({
      where: { id: existing.id },
      data: { role: 'ADMIN', passwordHash: await bcrypt.hash(password, 12) },
    });
    console.log(`Tài khoản Admin đã tồn tại. Đã cập nhật mật khẩu thành '${password}' và role thành ADMIN.`);
  } else {
    await prisma.user.create({
      data: {
        email,
        username,
        name: 'Quản trị viên',
        passwordHash: await bcrypt.hash(password, 12),
        role: 'ADMIN',
      },
    });
    console.log(`Tạo thành công tài khoản Admin mới:\n- Email: ${email}\n- Mật khẩu: ${password}`);
  }

  await app.close();
}
bootstrap();

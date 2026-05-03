const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const prisma = new PrismaClient();

async function run() {
  console.log('Đang khởi tạo tài khoản Admin...');
  const email = 'admin@phaptam.vn';
  const username = 'admin_pt';
  const password = '123';
  const hash = await bcrypt.hash(password, 12);

  const existing = await prisma.user.findFirst({ where: { email } });
  
  if (existing) {
    await prisma.user.update({
      where: { id: existing.id },
      data: { role: 'ADMIN', passwordHash: hash },
    });
    console.log(\`Tài khoản đã tồn tại. Đã cập nhật quyền ADMIN và reset mật khẩu thành: \${password}\`);
  } else {
    await prisma.user.create({
      data: {
        email,
        username,
        name: 'Quản trị viên',
        passwordHash: hash,
        role: 'ADMIN',
        acceptedTerms: true,
      },
    });
    console.log(\`Đã tạo tài khoản mới:\nEmail: \${email}\nMật khẩu: \${password}\`);
  }
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

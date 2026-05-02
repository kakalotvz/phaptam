import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService, private readonly jwt: JwtService) {}

  async register(data: { email: string; password: string; username: string; name?: string; birthDate?: string; acceptedTerms: boolean }) {
    if (!data.acceptedTerms) throw new BadRequestException('Bạn cần đồng ý điều khoản để đăng ký');
    const existing = await this.prisma.user.findFirst({
      where: { OR: [{ email: data.email }, { username: data.username }] },
    });
    if (existing) throw new ConflictException('Email hoặc tài khoản đã tồn tại');

    const user = await this.prisma.user.create({
      data: {
        email: data.email,
        username: data.username,
        name: data.name,
        birthDate: data.birthDate ? new Date(data.birthDate) : null,
        passwordHash: await bcrypt.hash(data.password, 12),
      },
      select: { id: true, email: true, username: true, name: true, birthDate: true, active: true, role: true },
    });
    return { user, accessToken: await this.sign(user.id, user.role) };
  }

  async login(email: string, password: string) {
    const user = await this.prisma.user.findFirst({ where: { OR: [{ email }, { username: email }] } });
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }
    if (!user.active) throw new UnauthorizedException('Tài khoản đang bị dừng hoạt động');
    return {
      user: { id: user.id, email: user.email, username: user.username, name: user.name, birthDate: user.birthDate, active: user.active, role: user.role },
      accessToken: await this.sign(user.id, user.role),
    };
  }

  async forgotPassword(email: string) {
    await this.prisma.user.findUnique({ where: { email } });
    return { ok: true, message: 'If the email exists, reset instructions will be sent.' };
  }

  private sign(sub: string, role: string) {
    return this.jwt.signAsync({ sub, role });
  }
}

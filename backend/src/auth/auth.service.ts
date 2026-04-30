import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService, private readonly jwt: JwtService) {}

  async register(email: string, password: string) {
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException('Email already exists');

    const user = await this.prisma.user.create({
      data: { email, passwordHash: await bcrypt.hash(password, 12) },
      select: { id: true, email: true, role: true },
    });
    return { user, accessToken: await this.sign(user.id, user.role) };
  }

  async login(email: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }
    return {
      user: { id: user.id, email: user.email, role: user.role },
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

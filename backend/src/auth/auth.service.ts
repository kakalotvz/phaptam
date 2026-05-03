import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly mail: MailService,
  ) {}

  async register(data: { email: string; password: string; username: string; name?: string; birthDate?: string; acceptedTerms: boolean }) {
    if (!data.acceptedTerms) throw new BadRequestException('Bạn cần đồng ý điều khoản để đăng ký');
    if (data.username.trim().toLowerCase() === 'admin') throw new BadRequestException('Tên đăng nhập này không được phép sử dụng');

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

  async login(identifier: string, password: string) {
    const user = await this.prisma.user.findFirst({ where: { OR: [{ email: identifier }, { username: identifier }] } });
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedException('Sai tài khoản hoặc mật khẩu');
    }
    if (!user.active) throw new UnauthorizedException('Tài khoản đang bị dừng hoạt động');
    return {
      user: { id: user.id, email: user.email, username: user.username, name: user.name, birthDate: user.birthDate, active: user.active, role: user.role },
      accessToken: await this.sign(user.id, user.role),
    };
  }

  async forgotPassword(identifier: string) {
    // Accept email or username
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ email: identifier }, { username: identifier }] },
    });
    // Always return success to prevent user enumeration
    if (!user) return { ok: true, message: 'Nếu tài khoản tồn tại, mã OTP sẽ được gửi đến email.' };

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await this.prisma.user.update({
      where: { id: user.id },
      data: { otp, otpExpiry },
    });

    await this.mail.sendOtpEmail(user.email, otp);
    return { ok: true, message: 'Nếu tài khoản tồn tại, mã OTP sẽ được gửi đến email.' };
  }

  async resetPassword(identifier: string, otp: string, newPassword: string) {
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ email: identifier }, { username: identifier }] },
    });
    if (!user || !user.otp || !user.otpExpiry) {
      throw new BadRequestException('Mã OTP không hợp lệ hoặc đã hết hạn');
    }
    if (user.otp !== otp) {
      throw new BadRequestException('Mã OTP không đúng');
    }
    if (user.otpExpiry < new Date()) {
      throw new BadRequestException('Mã OTP đã hết hạn. Vui lòng yêu cầu mã mới.');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash: await bcrypt.hash(newPassword, 12),
        otp: null,
        otpExpiry: null,
      },
    });

    return { ok: true, message: 'Đặt lại mật khẩu thành công. Vui lòng đăng nhập.' };
  }

  private sign(sub: string, role: string) {
    return this.jwt.signAsync({ sub, role });
  }
}

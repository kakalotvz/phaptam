import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModuleOptions, JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { createHmac, randomInt, timingSafeEqual } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';

const OTP_RECORD_VERSION = 'v1';
const MAX_OTP_ATTEMPTS = 5;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly mail: MailService,
    private readonly config: ConfigService,
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
    const normalizedIdentifier = identifier.trim();
    // Accept email or username
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ email: normalizedIdentifier }, { username: normalizedIdentifier }] },
    });
    // Always return success to prevent user enumeration
    if (!user) return { ok: true, message: 'Nếu tài khoản tồn tại, mã OTP sẽ được gửi đến email.' };

    const otp = randomInt(100000, 1000000).toString();
    const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await this.prisma.user.update({
      where: { id: user.id },
      data: { otp: this.createOtpRecord(otp), otpExpiry },
    });

    await this.mail.sendOtpEmail(user.email, otp);
    return { ok: true, message: 'Nếu tài khoản tồn tại, mã OTP sẽ được gửi đến email.' };
  }

  async resetPassword(identifier: string, otp: string, newPassword: string) {
    const normalizedIdentifier = identifier.trim();
    const normalizedOtp = otp.trim();
    if (!/^\d{6}$/.test(normalizedOtp)) {
      throw new BadRequestException('Mã OTP không hợp lệ hoặc đã hết hạn');
    }

    const user = await this.prisma.user.findFirst({
      where: { OR: [{ email: normalizedIdentifier }, { username: normalizedIdentifier }] },
    });
    if (!user || !user.otp || !user.otpExpiry) {
      throw new BadRequestException('Mã OTP không hợp lệ hoặc đã hết hạn');
    }
    if (user.otpExpiry < new Date()) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { otp: null, otpExpiry: null },
      });
      throw new BadRequestException('Mã OTP đã hết hạn. Vui lòng yêu cầu mã mới.');
    }
    const verification = this.verifyOtp(user.otp, normalizedOtp);
    if (!verification.ok) {
      const nextAttempts = verification.attempts + 1;
      if (verification.record) {
        await this.prisma.user.update({
          where: { id: user.id },
          data:
            nextAttempts >= MAX_OTP_ATTEMPTS
              ? { otp: null, otpExpiry: null }
              : { otp: this.formatOtpRecord(verification.record.digest, nextAttempts) },
        });
      }
      throw new BadRequestException(
        nextAttempts >= MAX_OTP_ATTEMPTS
          ? 'Mã OTP không hợp lệ hoặc đã hết hạn'
          : 'Mã OTP không đúng',
      );
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
    const expiresIn = (role === 'ADMIN'
      ? (this.config.get<string>('JWT_ADMIN_EXPIRES_IN') ?? '12h')
      : (this.config.get<string>('JWT_EXPIRES_IN') ?? '7d')) as NonNullable<JwtModuleOptions['signOptions']>['expiresIn'];
    return this.jwt.signAsync({ sub, role }, { expiresIn });
  }

  private createOtpRecord(otp: string) {
    return this.formatOtpRecord(this.hashOtp(otp), 0);
  }

  private formatOtpRecord(digest: string, attempts: number) {
    return `${OTP_RECORD_VERSION}:${attempts}:${digest}`;
  }

  private parseOtpRecord(value: string) {
    const [version, attemptsText, digest] = value.split(':');
    const attempts = Number(attemptsText);
    if (
      version !== OTP_RECORD_VERSION ||
      !Number.isInteger(attempts) ||
      attempts < 0 ||
      !/^[a-f0-9]{64}$/i.test(digest ?? '')
    ) {
      return null;
    }
    return { attempts, digest };
  }

  private verifyOtp(storedOtp: string, suppliedOtp: string) {
    const record = this.parseOtpRecord(storedOtp);
    if (record) {
      return {
        ok: this.safeCompareHex(record.digest, this.hashOtp(suppliedOtp)),
        attempts: record.attempts,
        record,
      };
    }

    return {
      ok: this.safeCompareText(storedOtp, suppliedOtp),
      attempts: 0,
      record: null,
    };
  }

  private hashOtp(otp: string) {
    const secret = this.config.get<string>('OTP_SECRET') ?? this.config.getOrThrow<string>('JWT_SECRET');
    return createHmac('sha256', secret).update(otp).digest('hex');
  }

  private safeCompareHex(left: string, right: string) {
    const leftBuffer = Buffer.from(left, 'hex');
    const rightBuffer = Buffer.from(right, 'hex');
    return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
  }

  private safeCompareText(left: string, right: string) {
    const leftBuffer = Buffer.from(left);
    const rightBuffer = Buffer.from(right);
    return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
  }
}

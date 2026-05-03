import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter;

  constructor(private readonly config: ConfigService) {
    this.transporter = nodemailer.createTransport({
      host: this.config.get<string>('SMTP_HOST', 'smtp.gmail.com'),
      port: this.config.get<number>('SMTP_PORT', 465),
      secure: true,
      auth: {
        user: this.config.get<string>('SMTP_USER'),
        pass: this.config.get<string>('SMTP_PASS'),
      },
    });
  }

  async sendOtpEmail(to: string, otp: string): Promise<void> {
    const from = this.config.get<string>('SMTP_FROM', 'Pháp Tâm <noreply@phaptam.vn>');
    try {
      await this.transporter.sendMail({
        from,
        to,
        subject: '[Pháp Tâm] Mã xác nhận đặt lại mật khẩu',
        html: `
          <div style="font-family: 'Segoe UI', sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; background: #fffcf0; border-radius: 16px; border: 1px solid #e8d9b0;">
            <h2 style="color: #8b5e3c; text-align: center; margin-bottom: 8px;">🙏 Pháp Tâm</h2>
            <p style="color: #555; text-align: center; margin-bottom: 24px;">Đặt lại mật khẩu</p>
            <p style="color: #333;">Xin chào,</p>
            <p style="color: #333;">Bạn (hoặc ai đó) đã yêu cầu đặt lại mật khẩu cho tài khoản có email này. Sử dụng mã OTP dưới đây để tiếp tục:</p>
            <div style="text-align: center; margin: 32px 0;">
              <span style="display: inline-block; font-size: 36px; font-weight: bold; letter-spacing: 12px; color: #8b5e3c; background: #f6f0dd; padding: 16px 32px; border-radius: 12px;">${otp}</span>
            </div>
            <p style="color: #888; font-size: 13px; text-align: center;">Mã có hiệu lực trong <strong>10 phút</strong>. Nếu bạn không yêu cầu điều này, hãy bỏ qua email này.</p>
          </div>
        `,
      });
      this.logger.log(`OTP email sent to ${to}`);
    } catch (err) {
      this.logger.error(`Failed to send OTP email to ${to}`, err);
      throw new Error('Không thể gửi email. Vui lòng kiểm tra cấu hình SMTP.');
    }
  }
}

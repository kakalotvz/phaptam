import { CanActivate, ExecutionContext, Injectable, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const token = this.extractTokenFromHeader(request);
    
    if (!token) throw new UnauthorizedException('Không có token xác thực');

    try {
      const payload = await this.jwt.verifyAsync<{ sub?: string; role?: Role }>(token);
      request['user'] = payload;
      
      if (!payload.sub || payload.role !== Role.ADMIN) {
        throw new ForbiddenException('Bạn không có quyền truy cập khu vực này');
      }

      const admin = await this.prisma.user.findFirst({
        where: { id: payload.sub, role: Role.ADMIN, active: true },
        select: { id: true },
      });
      if (!admin) {
        throw new ForbiddenException('Tài khoản quản trị không còn hiệu lực');
      }
    } catch (error) {
      if (error instanceof ForbiddenException) throw error;
      throw new UnauthorizedException('Token không hợp lệ hoặc đã hết hạn');
    }
    return true;
  }

  private extractTokenFromHeader(request: any): string | undefined {
    const [type, token] = request.headers.authorization?.split(' ') ?? [];
    return type === 'Bearer' ? token : undefined;
  }
}

import { Body, Controller, Post, Headers } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PresenceService } from './presence.service';

@Controller('presence')
export class PresenceController {
  constructor(
    private readonly presence: PresenceService,
    private readonly jwt: JwtService,
  ) {}

  @Post('heartbeat')
  async heartbeat(@Body() data: { clientId?: string }, @Headers('authorization') authorization?: string) {
    const clientId = data.clientId?.trim();
    if (!clientId) return this.presence.stats();

    return this.presence.heartbeat(clientId, await this.userIdFromAuthorization(authorization));
  }

  @Post('leave')
  leave(@Body() data: { clientId?: string }) {
    const clientId = data.clientId?.trim();
    if (!clientId) return this.presence.stats();
    return this.presence.leave(clientId);
  }

  private async userIdFromAuthorization(authorization?: string) {
    const [type, token] = authorization?.split(' ') ?? [];
    if (type !== 'Bearer' || !token) return null;

    try {
      const payload = await this.jwt.verifyAsync<{ sub?: string }>(token);
      return payload.sub ?? null;
    } catch {
      return null;
    }
  }
}

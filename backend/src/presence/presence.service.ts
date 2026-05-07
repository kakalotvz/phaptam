import { Injectable } from '@nestjs/common';

const PRESENCE_TTL_MS = 45_000;

type PresenceSession = {
  clientId: string;
  userId: string | null;
  lastSeenAt: number;
};

export type PresenceStats = {
  activeAppCount: number;
  onlineAccountCount: number;
  generatedAt: string;
  ttlSeconds: number;
};

@Injectable()
export class PresenceService {
  private readonly sessions = new Map<string, PresenceSession>();

  heartbeat(clientId: string, userId?: string | null) {
    const normalizedClientId = clientId.trim();
    if (!normalizedClientId) return this.stats();

    this.sessions.set(normalizedClientId, {
      clientId: normalizedClientId,
      userId: userId ?? null,
      lastSeenAt: Date.now(),
    });

    return this.stats();
  }

  leave(clientId: string) {
    const normalizedClientId = clientId.trim();
    if (normalizedClientId) this.sessions.delete(normalizedClientId);
    return this.stats();
  }

  stats(): PresenceStats {
    this.pruneExpired();

    const onlineUserIds = new Set<string>();
    this.sessions.forEach((session) => {
      if (session.userId) onlineUserIds.add(session.userId);
    });

    return {
      activeAppCount: this.sessions.size,
      onlineAccountCount: onlineUserIds.size,
      generatedAt: new Date().toISOString(),
      ttlSeconds: Math.round(PRESENCE_TTL_MS / 1000),
    };
  }

  private pruneExpired() {
    const cutoff = Date.now() - PRESENCE_TTL_MS;
    this.sessions.forEach((session, clientId) => {
      if (session.lastSeenAt < cutoff) this.sessions.delete(clientId);
    });
  }
}

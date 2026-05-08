import { Transform } from 'class-transformer';
import { IsBoolean, IsEmail, IsEnum, IsInt, IsISO8601, IsOptional, IsString, IsUrl, Max, Min, MinLength } from 'class-validator';
import { NewsContentType, NewsSourceType, Role } from '@prisma/client';

function emptyToUndefined({ value }: { value: unknown }) {
  return typeof value === 'string' && value.trim() === '' ? undefined : value;
}

export class UpdateSettingsDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  contentPageSize?: number;
}

export class CreateAdminUserDto {
  @IsEmail()
  email!: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  username?: string;

  @IsString()
  @MinLength(8)
  password!: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  name?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsISO8601()
  birthDate?: string;

  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}

export class UpdateAdminUserDto {
  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  username?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  name?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  @MinLength(8)
  password?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsISO8601()
  birthDate?: string;

  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}

export class CreateRssSourceDto {
  @IsString()
  name!: string;

  @IsUrl({ require_protocol: true, protocols: ['http', 'https'] })
  url!: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}

export class UpdateRssSourceDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsUrl({ require_protocol: true, protocols: ['http', 'https'] })
  url?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}

export class CreateNewsCategoryDto {
  @IsString()
  name!: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  description?: string;

  @IsOptional()
  @IsEnum(NewsContentType)
  contentType?: NewsContentType;
}

export class CreateNewsItemDto {
  @IsString()
  title!: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  summary?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  content?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  imageUrl?: string;

  @IsOptional()
  @IsString()
  link?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  categoryId?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  sourceName?: string;

  @IsOptional()
  @IsEnum(NewsSourceType)
  sourceType?: NewsSourceType;

  @IsOptional()
  @IsEnum(NewsContentType)
  contentType?: NewsContentType;

  @IsOptional()
  @IsBoolean()
  shareEnabled?: boolean;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsISO8601()
  publishedAt?: string;
}

export class UpdateNewsItemDto {
  @IsOptional()
  @IsString()
  title?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  summary?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  content?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  imageUrl?: string;

  @IsOptional()
  @IsString()
  link?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  categoryId?: string;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsString()
  sourceName?: string;

  @IsOptional()
  @IsEnum(NewsSourceType)
  sourceType?: NewsSourceType;

  @IsOptional()
  @IsEnum(NewsContentType)
  contentType?: NewsContentType;

  @IsOptional()
  @IsBoolean()
  shareEnabled?: boolean;

  @IsOptional()
  @Transform(emptyToUndefined)
  @IsISO8601()
  publishedAt?: string;
}

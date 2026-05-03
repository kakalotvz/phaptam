import { Body, Controller, Post } from '@nestjs/common';
import { IsBoolean, IsEmail, IsISO8601, IsOptional, IsString, MinLength } from 'class-validator';
import { AuthService } from './auth.service';

class LoginDto {
  @IsString()
  email!: string;

  @IsString()
  @MinLength(8)
  password!: string;
}

class RegisterDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8)
  password!: string;

  @IsString()
  username!: string;

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsISO8601()
  birthDate?: string;

  @IsBoolean()
  acceptedTerms!: boolean;
}

class ResetPasswordDto {
  @IsString()
  identifier!: string;

  @IsString()
  otp!: string;

  @IsString()
  @MinLength(8)
  newPassword!: string;
}

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto.email, dto.password);
  }

  @Post('forgot-password')
  forgotPassword(@Body('identifier') identifier: string) {
    return this.auth.forgotPassword(identifier);
  }

  @Post('reset-password')
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto.identifier, dto.otp, dto.newPassword);
  }
}

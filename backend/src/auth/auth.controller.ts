import { Body, Controller, Post } from '@nestjs/common';
import { IsBoolean, IsEmail, IsISO8601, IsOptional, IsString, MinLength } from 'class-validator';
import { AuthService } from './auth.service';

class AuthDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8)
  password!: string;
}

class RegisterDto extends AuthDto {
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

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Post('login')
  login(@Body() dto: AuthDto) {
    return this.auth.login(dto.email, dto.password);
  }

  @Post('forgot-password')
  forgotPassword(@Body('email') email: string) {
    return this.auth.forgotPassword(email);
  }
}

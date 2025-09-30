import 'dotenv/config';
import process from 'process';
import { z } from 'zod';

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  POOL_MAX: z.coerce.number().min(1).default(10),
  POOL_IDLE_TIMEOUT: z.coerce.number().min(0).default(10000),
  JWT_ACCESS_SECRET: z.string().min(10),
  JWT_REFRESH_SECRET: z.string().min(10),
  JWT_ACCESS_TTL: z.string().default('15m'),
  JWT_REFRESH_TTL: z.string().default('30d'),
  BCRYPT_ROUNDS: z.coerce.number().min(4).max(15).default(12),
  PORT: z.coerce.number().min(1).default(8080),
  APP_URL: z.string().url(),
  FRONTEND_ORIGINS: z.string().optional(),
  UPLOADS_BASE_PATH: z.string().default('./uploads'),
  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.string().optional(),
  SMTP_USER: z.string().optional(),
  SMTP_PASSWORD: z.string().optional(),
  SMS_PROVIDER_API_KEY: z.string().optional()
});

const parsed = envSchema.parse({
  DATABASE_URL: process.env.DATABASE_URL,
  POOL_MAX: process.env.POOL_MAX,
  POOL_IDLE_TIMEOUT: process.env.POOL_IDLE_TIMEOUT,
  JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET,
  JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET,
  JWT_ACCESS_TTL: process.env.JWT_ACCESS_TTL,
  JWT_REFRESH_TTL: process.env.JWT_REFRESH_TTL,
  BCRYPT_ROUNDS: process.env.BCRYPT_ROUNDS,
  PORT: process.env.PORT,
  APP_URL: process.env.APP_URL,
  FRONTEND_ORIGINS: process.env.FRONTEND_ORIGINS,
  UPLOADS_BASE_PATH: process.env.UPLOADS_BASE_PATH,
  SMTP_HOST: process.env.SMTP_HOST,
  SMTP_PORT: process.env.SMTP_PORT,
  SMTP_USER: process.env.SMTP_USER,
  SMTP_PASSWORD: process.env.SMTP_PASSWORD,
  SMS_PROVIDER_API_KEY: process.env.SMS_PROVIDER_API_KEY
});

const frontendOrigins = parsed.FRONTEND_ORIGINS
  ? parsed.FRONTEND_ORIGINS.split(',').map((origin) => origin.trim()).filter(Boolean)
  : [];

export const env = {
  databaseUrl: parsed.DATABASE_URL,
  poolMax: parsed.POOL_MAX,
  poolIdleTimeout: parsed.POOL_IDLE_TIMEOUT,
  jwt: {
    accessSecret: parsed.JWT_ACCESS_SECRET,
    refreshSecret: parsed.JWT_REFRESH_SECRET,
    accessTtl: parsed.JWT_ACCESS_TTL,
    refreshTtl: parsed.JWT_REFRESH_TTL
  },
  bcryptRounds: parsed.BCRYPT_ROUNDS,
  server: {
    port: parsed.PORT,
    appUrl: parsed.APP_URL,
    corsOrigins: frontendOrigins
  },
  uploadsBasePath: parsed.UPLOADS_BASE_PATH,
  smtp: {
    host: parsed.SMTP_HOST,
    port: parsed.SMTP_PORT ? Number(parsed.SMTP_PORT) : undefined,
    user: parsed.SMTP_USER,
    password: parsed.SMTP_PASSWORD
  },
  smsProviderApiKey: parsed.SMS_PROVIDER_API_KEY
};

export default env;

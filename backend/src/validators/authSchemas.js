import { z } from 'zod';

export const signupStep1Schema = z.object({
  fullName: z.string().min(3).max(150),
  username: z.string().min(3).max(40).regex(/^[a-zA-Z0-9_]+$/),
  email: z.string().email(),
  password: z.string().min(8),
  phoneCountryCode: z.string().min(1).max(6),
  phoneNumber: z.string().min(6).max(20)
});

export const signupStep2Schema = z.object({
  userId: z.number().int().positive(),
  idNumber: z.string().min(6).max(50),
  frontIdUrl: z.string().url(),
  backIdUrl: z.string().url()
});

export const signupStep3Schema = z.object({
  userId: z.number().int().positive(),
  selfieUrl: z.string().url()
});

export const loginSchema = z.object({
  identifier: z.string().min(3),
  password: z.string().min(8)
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(10)
});

export const requestPhoneCodeSchema = z.object({
  userId: z.number().int().positive()
});

export const verifyPhoneSchema = z.object({
  userId: z.number().int().positive(),
  code: z.string().min(4).max(8)
});

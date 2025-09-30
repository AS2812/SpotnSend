import { z } from 'zod';

export const updateProfileSchema = z.object({
  email: z.string().email().optional(),
  phoneCountryCode: z.string().min(1).max(6).optional(),
  phoneNumber: z.string().min(6).max(20).optional()
}).refine((data) => Object.keys(data).length > 0, {
  message: 'No changes provided'
});

export const updateSettingsSchema = z.object({
  language: z.enum(['en', 'ar']).optional(),
  theme: z.enum(['light', 'dark', 'system']).optional(),
  twoFactorPrompt: z.boolean().optional()
}).refine((data) => Object.keys(data).length > 0, {
  message: 'No changes provided'
});

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(8),
  newPassword: z.string().min(8)
});

export const notificationPreferencesSchema = z.object({
  notificationsEnabled: z.boolean().optional(),
  pushEnabled: z.boolean().optional(),
  emailEnabled: z.boolean().optional(),
  smsEnabled: z.boolean().optional()
});

export const favoriteSpotSchema = z.object({
  name: z.string().min(2).max(80),
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
  radiusMeters: z.coerce.number().int().min(50).max(20000).optional()
});

export const mapPreferencesSchema = z.object({
  defaultRadiusMeters: z.coerce.number().int().min(50).max(20000).optional(),
  defaultView: z.enum(['map', 'list']).optional(),
  includeFavoritesByDefault: z.boolean().optional()
});

export const categoryFiltersSchema = z.object({
  categoryIds: z.array(z.coerce.number().int().positive()).optional()
});

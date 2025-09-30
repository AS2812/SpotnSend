import { z } from 'zod';

export const createReportSchema = z.object({
  categoryId: z.coerce.number().int().positive(),
  subcategoryId: z.coerce.number().int().positive().optional(),
  description: z.string().min(10),
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
  locationName: z.string().max(255).optional(),
  address: z.string().max(255).optional(),
  city: z.string().max(120).optional(),
  alertRadiusMeters: z.coerce.number().int().min(50).max(20000).optional(),
  notifyScope: z.enum(['people', 'government', 'both']).default('people'),
  priority: z.enum(['low', 'normal', 'high', 'critical']).default('normal'),
  media: z.array(z.object({
    url: z.string().url(),
    kind: z.enum(['image', 'video']).default('image'),
    isCover: z.boolean().optional()
  })).max(5).optional()
});

export const nearbyReportsSchema = z.object({
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().min(50).max(50000).default(1000),
  categories: z
    .string()
    .transform((val) => val.split(',').map((item) => Number(item)).filter(Boolean))
    .optional(),
  subcategories: z
    .string()
    .transform((val) => val.split(',').map((item) => Number(item)).filter(Boolean))
    .optional(),
  statuses: z
    .string()
    .transform((val) => val.split(',').filter(Boolean))
    .optional(),
  limit: z.coerce.number().min(1).max(100).default(50),
  offset: z.coerce.number().min(0).default(0)
});

export const authoritiesNearbySchema = z.object({
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().min(100).max(200000).default(20000),
  categoryIds: z
    .string()
    .transform((val) => val.split(',').map((item) => Number(item)).filter(Boolean))
    .optional(),
  limit: z.coerce.number().min(1).max(50).default(20)
});

export const reportFeedbackSchema = z.object({
  comment: z.string().min(3).max(2000)
});

export const reportFlagSchema = z.object({
  reason: z.enum(['spam', 'misleading', 'duplicate', 'test', 'other']),
  details: z.string().max(500).optional()
});

export const reportStatusUpdateSchema = z.object({
  status: z.enum(['submitted', 'under_review', 'approved', 'rejected', 'archived']).optional(),
  priority: z.enum(['low', 'normal', 'high', 'critical']).optional(),
  notes: z.string().optional()
}).refine((data) => data.status || data.priority || data.notes, {
  message: 'Provide at least one field to update'
});

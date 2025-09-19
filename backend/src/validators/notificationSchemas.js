import { z } from 'zod';

export const sendNotificationSchema = z.object({
  userId: z.number().int().positive(),
  title: z.string().min(3),
  body: z.string().min(3),
  notificationType: z.enum(['system', 'report_update', 'verification', 'reminder']).default('system'),
  relatedReportId: z.number().int().positive().optional(),
  payload: z.record(z.any()).optional()
});

export const markNotificationSchema = z.object({
  ids: z.array(z.number().int().positive()).min(1)
});

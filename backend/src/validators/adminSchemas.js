import { z } from 'zod';

export const adminReportFilterSchema = z.object({
  status: z.string().optional(),
  priority: z.string().optional(),
  categoryId: z.coerce.number().int().optional(),
  city: z.string().optional(),
  page: z.coerce.number().min(1).optional(),
  limit: z.coerce.number().min(1).max(100).optional()
});

export const dispatchUpdateSchema = z.object({
  status: z.enum(['pending', 'notified', 'acknowledged', 'dismissed']),
  notes: z.string().optional()
});

export const updateUserStatusSchema = z.object({
  status: z.enum(['pending', 'verified', 'suspended'])
});

export const reviewVerificationSchema = z.object({
  status: z.enum(['approved', 'rejected', 'cancelled']),
  rejectionReason: z.string().optional(),
  notes: z.string().optional()
});

export const auditEventsFilterSchema = z.object({
  tableName: z.string().optional(),
  recordId: z.string().optional(),
  page: z.coerce.number().min(1).optional(),
  limit: z.coerce.number().min(1).max(100).optional()
});

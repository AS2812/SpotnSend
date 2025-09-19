import { Router } from 'express';
import { authenticate, requireRoles } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import {
  handleListUsers,
  handleUpdateUserStatus,
  handlePendingVerifications,
  handleReviewVerification,
  handleAuditEvents
} from '../controllers/adminController.js';
import {
  updateUserStatusSchema,
  reviewVerificationSchema,
  auditEventsFilterSchema
} from '../validators/adminSchemas.js';

const router = Router();

router.use(authenticate());
router.use(requireRoles('moderator', 'admin'));

router.get('/users', handleListUsers);
router.patch('/users/:id/status', validate(updateUserStatusSchema), handleUpdateUserStatus);

router.get('/verifications/pending', handlePendingVerifications);
router.patch('/verifications/:id', validate(reviewVerificationSchema), handleReviewVerification);

router.get('/audit-events', validate(auditEventsFilterSchema, 'query'), handleAuditEvents);

export default router;

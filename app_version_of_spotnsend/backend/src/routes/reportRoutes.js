import { Router } from 'express';
import { authenticate, requireRoles } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { upload } from '../middleware/uploads.js';
import { reportCreationLimiter } from '../middleware/rateLimiters.js';
import {
  createReportSchema,
  nearbyReportsSchema,
  authoritiesNearbySchema,
  reportFeedbackSchema,
  reportFlagSchema,
  reportStatusUpdateSchema
} from '../validators/reportSchemas.js';
import { dispatchUpdateSchema } from '../validators/adminSchemas.js';
import {
  handleCreateReport,
  handleGetReport,
  handleListMyReports,
  handleNearbyReports,
  handleAddFeedback,
  handleFlagReport,
  handleUpdateReportStatus,
  handleAdminReports,
  handleUpdateDispatch,
  handleAuthoritiesNearby
} from '../controllers/reportController.js';

const router = Router();

router.get('/nearby', validate(nearbyReportsSchema, 'query'), handleNearbyReports);
router.get('/authorities/nearby', validate(authoritiesNearbySchema, 'query'), handleAuthoritiesNearby);
router.get('/:id(\\d+)', authenticate({ optional: true }), handleGetReport);

router.use(authenticate());

router.post('/', reportCreationLimiter, upload.array('mediaFiles', 5), validate(createReportSchema), handleCreateReport);
router.get('/me/list', handleListMyReports);
router.post('/:id(\\d+)/feedback', validate(reportFeedbackSchema), handleAddFeedback);
router.post('/:id(\\d+)/flag', validate(reportFlagSchema), handleFlagReport);

router.patch('/:id(\\d+)/status', requireRoles('moderator', 'admin'), validate(reportStatusUpdateSchema), handleUpdateReportStatus);
router.get('/admin/list', requireRoles('moderator', 'admin'), handleAdminReports);
router.patch('/dispatch/:id(\\d+)', requireRoles('moderator', 'admin'), validate(dispatchUpdateSchema), handleUpdateDispatch);

export default router;

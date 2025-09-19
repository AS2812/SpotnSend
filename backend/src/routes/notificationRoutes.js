import { Router } from 'express';
import { authenticate, requireRoles } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import {
  handleListNotifications,
  handleMarkNotifications,
  handleDeleteNotifications,
  handleSendNotification,
  handleGetNotification
} from '../controllers/notificationController.js';
import { markNotificationSchema, sendNotificationSchema } from '../validators/notificationSchemas.js';

const router = Router();

router.use(authenticate());

router.get('/', handleListNotifications);
router.get('/:id', handleGetNotification);
router.post('/mark', validate(markNotificationSchema), handleMarkNotifications);
router.post('/delete', validate(markNotificationSchema), handleDeleteNotifications);

router.post('/send', requireRoles('moderator', 'admin'), validate(sendNotificationSchema), handleSendNotification);

export default router;

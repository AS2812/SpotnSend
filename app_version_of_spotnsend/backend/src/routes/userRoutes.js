import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import {
  updateProfileSchema,
  updateSettingsSchema,
  notificationPreferencesSchema,
  favoriteSpotSchema,
  mapPreferencesSchema,
  categoryFiltersSchema
} from '../validators/userSchemas.js';
import {
  handleGetProfile,
  handleUpdateProfile,
  handleGetSettings,
  handleUpdateSettings,
  handleGetNotificationPreferences,
  handleUpdateNotificationPreferences,
  handleListFavoriteSpots,
  handleCreateFavoriteSpot,
  handleDeleteFavoriteSpot,
  handleGetMapPreferences,
  handleUpdateMapPreferences,
  handleGetCategoryFilters,
  handleUpdateCategoryFilters
} from '../controllers/userController.js';

const router = Router();

router.use(authenticate());

router.get('/profile', handleGetProfile);
router.patch('/profile', validate(updateProfileSchema), handleUpdateProfile);

router.get('/settings', handleGetSettings);
router.put('/settings', validate(updateSettingsSchema), handleUpdateSettings);

router.get('/notification-preferences', handleGetNotificationPreferences);
router.put('/notification-preferences', validate(notificationPreferencesSchema), handleUpdateNotificationPreferences);

router.get('/favorite-spots', handleListFavoriteSpots);
router.post('/favorite-spots', validate(favoriteSpotSchema), handleCreateFavoriteSpot);
router.delete('/favorite-spots/:id', handleDeleteFavoriteSpot);

router.get('/map-preferences', handleGetMapPreferences);
router.put('/map-preferences', validate(mapPreferencesSchema), handleUpdateMapPreferences);

router.get('/category-filters', handleGetCategoryFilters);
router.put('/category-filters', validate(categoryFiltersSchema), handleUpdateCategoryFilters);

export default router;

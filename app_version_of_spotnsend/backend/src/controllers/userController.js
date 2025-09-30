import { getUserById } from '../services/authService.js';
import {
  updateProfile,
  updateSettings,
  getSettings,
  getAccountStats,
  getNotificationPreferences,
  updateNotificationPreferences,
  listFavoriteSpots,
  createFavoriteSpot,
  deleteFavoriteSpot,
  getMapPreferences,
  updateMapPreferences,
  setCategoryFilters,
  listCategoryFilters
} from '../services/userService.js';

export async function handleGetProfile(req, res, next) {
  try {
    const [profile, stats] = await Promise.all([
      getUserById(req.user.sub),
      getAccountStats(req.user.sub)
    ]);
    res.json({ profile, stats });
  } catch (error) {
    next(error);
  }
}

export async function handleUpdateProfile(req, res, next) {
  try {
    const updated = await updateProfile(req.user.sub, req.body);
    res.json(updated);
  } catch (error) {
    next(error);
  }
}

export async function handleGetSettings(req, res, next) {
  try {
    const settings = await getSettings(req.user.sub);
    res.json(settings);
  } catch (error) {
    next(error);
  }
}

export async function handleUpdateSettings(req, res, next) {
  try {
    const result = await updateSettings(req.user.sub, req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

export async function handleGetNotificationPreferences(req, res, next) {
  try {
    const prefs = await getNotificationPreferences(req.user.sub);
    res.json(prefs);
  } catch (error) {
    next(error);
  }
}

export async function handleUpdateNotificationPreferences(req, res, next) {
  try {
    const prefs = await updateNotificationPreferences(req.user.sub, req.body);
    res.json(prefs);
  } catch (error) {
    next(error);
  }
}

export async function handleListFavoriteSpots(req, res, next) {
  try {
    const spots = await listFavoriteSpots(req.user.sub);
    res.json(spots);
  } catch (error) {
    next(error);
  }
}

export async function handleCreateFavoriteSpot(req, res, next) {
  try {
    const spot = await createFavoriteSpot(req.user.sub, req.body);
    res.status(201).json(spot);
  } catch (error) {
    next(error);
  }
}

export async function handleDeleteFavoriteSpot(req, res, next) {
  try {
    await deleteFavoriteSpot(req.user.sub, Number(req.params.id));
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}

export async function handleGetMapPreferences(req, res, next) {
  try {
    const prefs = await getMapPreferences(req.user.sub);
    res.json(prefs);
  } catch (error) {
    next(error);
  }
}

export async function handleUpdateMapPreferences(req, res, next) {
  try {
    const prefs = await updateMapPreferences(req.user.sub, req.body);
    res.json(prefs);
  } catch (error) {
    next(error);
  }
}

export async function handleGetCategoryFilters(req, res, next) {
  try {
    const filters = await listCategoryFilters(req.user.sub);
    res.json(filters);
  } catch (error) {
    next(error);
  }
}

export async function handleUpdateCategoryFilters(req, res, next) {
  try {
    const categories = Array.isArray(req.body.categoryIds) ? req.body.categoryIds : [];
    const result = await setCategoryFilters(req.user.sub, categories);
    res.json({ categoryIds: result });
  } catch (error) {
    next(error);
  }
}

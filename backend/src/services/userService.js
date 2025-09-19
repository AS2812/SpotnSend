import createError from 'http-errors';
import { db, withTransaction } from '../config/db.js';

export async function updateProfile(userId, { email, phoneCountryCode, phoneNumber }) {
  const res = await db.query(
    `UPDATE civic_app.users
     SET email = COALESCE($2, email),
         phone_country_code = COALESCE($3, phone_country_code),
         phone_number = COALESCE($4, phone_number),
         updated_at = NOW()
     WHERE user_id = $1
     RETURNING user_id, email, phone_country_code, phone_number, account_status`,
    [userId, email, phoneCountryCode, phoneNumber]
  );
  if (res.rowCount === 0) throw createError(404, 'User not found');
  return res.rows[0];
}

export async function updateSettings(userId, { language, theme, twoFactorPrompt }) {
  const res = await db.query(
    `INSERT INTO civic_app.user_settings (user_id, language, theme, two_factor_prompt)
     VALUES ($1, COALESCE($2, 'en'), COALESCE($3, 'light'), COALESCE($4, FALSE))
     ON CONFLICT (user_id) DO UPDATE SET
       language = COALESCE(EXCLUDED.language, civic_app.user_settings.language),
       theme = COALESCE(EXCLUDED.theme, civic_app.user_settings.theme),
       two_factor_prompt = COALESCE(EXCLUDED.two_factor_prompt, civic_app.user_settings.two_factor_prompt),
       updated_at = NOW()
     RETURNING user_id, language, theme, two_factor_prompt, updated_at`,
    [userId, language, theme, twoFactorPrompt]
  );
  return res.rows[0];
}

export async function getSettings(userId) {
  const res = await db.query(
    `SELECT language, theme, two_factor_prompt, updated_at
     FROM civic_app.user_settings WHERE user_id = $1`,
    [userId]
  );
  return res.rows[0] || null;
}

export async function getAccountStats(userId) {
  const stats = await db.query(
    `SELECT
        (SELECT COUNT(*) FROM civic_app.reports WHERE user_id = $1) AS reports_count,
        (SELECT COUNT(*) FROM civic_app.report_feedbacks WHERE user_id = $1) AS feedback_count,
        (SELECT account_status FROM civic_app.users WHERE user_id = $1) AS account_status`,
    [userId]
  );
  if (stats.rowCount === 0) throw createError(404, 'User not found');
  return stats.rows[0];
}

export async function getNotificationPreferences(userId) {
  const res = await db.query(
    `SELECT notifications_enabled, push_enabled, email_enabled, sms_enabled
     FROM civic_app.user_notification_preferences WHERE user_id = $1`,
    [userId]
  );
  if (res.rowCount === 0) {
    return null;
  }
  return res.rows[0];
}

export async function updateNotificationPreferences(userId, prefs) {
  const { notificationsEnabled, pushEnabled, emailEnabled, smsEnabled } = prefs;
  const res = await db.query(
    `INSERT INTO civic_app.user_notification_preferences (
        user_id, notifications_enabled, push_enabled, email_enabled, sms_enabled
     ) VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id) DO UPDATE SET
        notifications_enabled = COALESCE(EXCLUDED.notifications_enabled, civic_app.user_notification_preferences.notifications_enabled),
        push_enabled = COALESCE(EXCLUDED.push_enabled, civic_app.user_notification_preferences.push_enabled),
        email_enabled = COALESCE(EXCLUDED.email_enabled, civic_app.user_notification_preferences.email_enabled),
        sms_enabled = COALESCE(EXCLUDED.sms_enabled, civic_app.user_notification_preferences.sms_enabled),
        updated_at = NOW()
     RETURNING notifications_enabled, push_enabled, email_enabled, sms_enabled, updated_at`,
    [userId, notificationsEnabled, pushEnabled, emailEnabled, smsEnabled]
  );
  return res.rows[0];
}

export async function listFavoriteSpots(userId) {
  const res = await db.query(
    `SELECT favorite_spot_id, name, latitude, longitude, radius_meters, created_at
     FROM civic_app.favorite_spots WHERE user_id = $1 ORDER BY created_at DESC`,
    [userId]
  );
  return res.rows;
}

export async function createFavoriteSpot(userId, { name, latitude, longitude, radiusMeters }) {
  const res = await db.query(
    `INSERT INTO civic_app.favorite_spots (user_id, name, latitude, longitude, radius_meters)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING favorite_spot_id, name, latitude, longitude, radius_meters, created_at`,
    [userId, name, latitude, longitude, radiusMeters]
  );
  return res.rows[0];
}

export async function deleteFavoriteSpot(userId, spotId) {
  const res = await db.query(
    `DELETE FROM civic_app.favorite_spots WHERE favorite_spot_id = $1 AND user_id = $2`,
    [spotId, userId]
  );
  if (res.rowCount === 0) throw createError(404, 'Favorite spot not found');
}

export async function getMapPreferences(userId) {
  const res = await db.query(
    `SELECT default_radius_meters, default_view, include_favorites_by_default
     FROM civic_app.user_map_preferences WHERE user_id = $1`,
    [userId]
  );
  return res.rows[0] || null;
}

export async function updateMapPreferences(userId, prefs) {
  const { defaultRadiusMeters, defaultView, includeFavoritesByDefault } = prefs;
  const res = await db.query(
    `INSERT INTO civic_app.user_map_preferences (user_id, default_radius_meters, default_view, include_favorites_by_default)
     VALUES ($1, COALESCE($2, 1000), COALESCE($3, 'map'), COALESCE($4, TRUE))
     ON CONFLICT (user_id) DO UPDATE SET
       default_radius_meters = COALESCE(EXCLUDED.default_radius_meters, civic_app.user_map_preferences.default_radius_meters),
       default_view = COALESCE(EXCLUDED.default_view, civic_app.user_map_preferences.default_view),
       include_favorites_by_default = COALESCE(EXCLUDED.include_favorites_by_default, civic_app.user_map_preferences.include_favorites_by_default),
       updated_at = NOW()
     RETURNING default_radius_meters, default_view, include_favorites_by_default, updated_at`,
    [userId, defaultRadiusMeters, defaultView, includeFavoritesByDefault]
  );
  return res.rows[0];
}

export async function setCategoryFilters(userId, categoryIds) {
  return withTransaction(async (client) => {
    await client.query(`DELETE FROM civic_app.user_category_filters WHERE user_id = $1`, [userId]);
    if (!categoryIds || categoryIds.length === 0) return [];
    const values = categoryIds.map((_, index) => `($1, $${index + 2}, TRUE)`).join(', ');
    const params = [userId, ...categoryIds];
    await client.query(
      `INSERT INTO civic_app.user_category_filters (user_id, category_id, is_selected)
       VALUES ${values}`,
      params
    );
    return categoryIds;
  });
}

export async function listCategoryFilters(userId) {
  const res = await db.query(
    `SELECT category_id, is_selected FROM civic_app.user_category_filters WHERE user_id = $1`,
    [userId]
  );
  return res.rows;
}

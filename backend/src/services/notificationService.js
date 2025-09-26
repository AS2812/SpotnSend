import { db, withTransaction } from '../config/db.js'
import createError from 'http-errors'

export async function listNotifications (userId, query = {}) {
  const limit = Math.min(Number(query.limit) || 50, 100)
  const offset = Math.max(Number(query.offset) || 0, 0)
  const res = await db.query(
    `SELECT notification_id, notification_type, title, body, payload, related_report_id,
            created_at, seen_at
  FROM public.notifications
     WHERE user_id = $1 AND deleted_at IS NULL
     ORDER BY created_at DESC
     LIMIT $2 OFFSET $3`,
    [userId, limit, offset]
  )
  return res.rows
}

export async function markNotificationsSeen (userId, ids) {
  if (!ids || ids.length === 0) return []
  const res = await db.query(
  `UPDATE public.notifications
     SET seen_at = NOW()
     WHERE user_id = $1 AND notification_id = ANY($2::bigint[])
     RETURNING notification_id, seen_at`,
  [userId, ids]
  )
  return res.rows
}

export async function deleteNotifications (userId, ids) {
  if (!ids || ids.length === 0) return []
  await db.query(
  `UPDATE public.notifications
     SET deleted_at = NOW()
     WHERE user_id = $1 AND notification_id = ANY($2::bigint[])`,
  [userId, ids]
  )
  return ids
}

export async function sendNotification ({ userId, title, body, notificationType, payload, relatedReportId }, channels = ['in_app']) {
  return withTransaction(async (client) => {
    const notificationRes = await client.query(
  `INSERT INTO public.notifications (user_id, notification_type, title, body, payload, related_report_id)
       VALUES ($1, $2, $3, $4, COALESCE($5, '{}'::jsonb), $6)
       RETURNING notification_id, user_id, notification_type, title, body, payload, related_report_id, created_at`,
  [userId, notificationType || 'system', title, body, payload || null, relatedReportId || null]
    )
    const notification = notificationRes.rows[0]

    if (channels && channels.length > 0) {
      const placeholders = channels.map((_, index) => `($1, $${index + 2}, 'pending')`).join(', ')
      const params = [notification.notification_id, ...channels]
      await client.query(
  `INSERT INTO public.notification_deliveries (notification_id, channel, status)
         VALUES ${placeholders}
         ON CONFLICT (notification_id, channel) DO NOTHING`,
  params
      )
    }

    return notification
  })
}

export async function getNotificationById (notificationId, userId) {
  const res = await db.query(
    `SELECT notification_id, title, body, payload, created_at, seen_at
  FROM public.notifications
     WHERE notification_id = $1 AND user_id = $2`,
    [notificationId, userId]
  )
  if (res.rowCount === 0) throw createError(404, 'Notification not found')
  return res.rows[0]
}

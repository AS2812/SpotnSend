import createError from 'http-errors'
import format from 'pg-format'
import { db, withTransaction } from '../config/db.js'
import { buildPaginationMeta, getPagination } from '../utils/pagination.js'

const reportFields = `
  r.report_id,
  r.user_id,
  r.category_id,
  r.subcategory_id,
  r.status,
  r.priority,
  r.notify_scope,
  r.description,
  r.latitude,
  r.longitude,
  r.location_name,
  r.address,
  r.city,
  r.alert_radius_meters,
  r.government_ticket_ref,
  r.created_at,
  r.updated_at,
  r.resolved_at
`

export async function createReport (userId, payload) {
  const {
    categoryId,
    subcategoryId,
    description,
    latitude,
    longitude,
    locationName,
    address,
    city,
    alertRadiusMeters,
    notifyScope,
    priority,
    media = []
  } = payload

  return withTransaction(async (client) => {
    const reportRes = await client.query(
  `INSERT INTO public.reports (
         user_id, category_id, subcategory_id, description, latitude, longitude,
         location_name, address, city, alert_radius_meters, notify_scope, priority
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
       RETURNING ${reportFields}`,
  [
    userId,
    categoryId,
    subcategoryId || null,
    description,
    latitude,
    longitude,
    locationName || null,
    address || null,
    city || null,
    alertRadiusMeters || null,
    notifyScope || 'people',
    priority || 'normal'
  ]
    )

    const report = reportRes.rows[0]

    if (media.length > 0) {
      const values = media.map((item) => [
        report.report_id,
        item.kind || 'image',
        item.url,
        item.thumbnailUrl || null,
        item.metadata ? JSON.stringify(item.metadata) : '{}',
        item.isCover || false
      ])
      const insertMediaSql = format(
        'INSERT INTO public.report_media (report_id, media_type, storage_url, thumbnail_url, metadata, is_cover) VALUES %L',
        values
      )
      await client.query(insertMediaSql)
    }

    const categoriesArray = categoryId ? [categoryId] : null
    const authoritiesRes = await client.query(
      'SELECT authority_id FROM public.find_authorities_nearby($1, $2, $3, $4, $5)',
      [
        latitude,
        longitude,
        alertRadiusMeters || 5000,
        categoriesArray,
        10
      ]
    )

    if (authoritiesRes.rowCount > 0 && (notifyScope === 'government' || notifyScope === 'both')) {
      const values = authoritiesRes.rows.map((row) => [
        report.report_id,
        row.authority_id,
        'pending',
        'in_app'
      ])
      const sql = format(
        'INSERT INTO public.report_authority_dispatches (report_id, authority_id, status, channel) VALUES %L ON CONFLICT (report_id, authority_id) DO NOTHING',
        values
      )
      await client.query(sql)
    }

    return report
  })
}

export async function getReport (reportId) {
  const res = await db.query(
    `SELECT ${reportFields},
            c.name AS category_name,
            sc.name AS subcategory_name,
            u.full_name AS reporter_name,
            u.account_status,
            u.phone_number,
            u.phone_country_code
  FROM public.reports r
  JOIN public.report_categories c ON c.category_id = r.category_id
  LEFT JOIN public.report_subcategories sc ON sc.subcategory_id = r.subcategory_id
  JOIN public.users u ON u.user_id = r.user_id
     WHERE r.report_id = $1`,
    [reportId]
  )
  if (res.rowCount === 0) throw createError(404, 'Report not found')

  const mediaRes = await db.query(
    `SELECT media_id, media_type, storage_url, thumbnail_url, metadata, is_cover, created_at
  FROM public.report_media WHERE report_id = $1`,
    [reportId]
  )

  const feedbackRes = await db.query(
    `SELECT rf.feedback_id, rf.user_id, rf.feedback_type, rf.comment, rf.created_at,
            u.full_name
  FROM public.report_feedbacks rf
  JOIN public.users u ON u.user_id = rf.user_id
     WHERE rf.report_id = $1
     ORDER BY rf.created_at DESC`,
    [reportId]
  )

  const dispatchRes = await db.query(
    `SELECT rad.dispatch_id, rad.authority_id, a.name AS authority_name, rad.status,
            rad.channel, rad.notified_at, rad.acknowledged_at, rad.dismissed_at, rad.notes
  FROM public.report_authority_dispatches rad
  JOIN public.authorities a ON a.authority_id = rad.authority_id
     WHERE rad.report_id = $1`,
    [reportId]
  )

  return {
    ...res.rows[0],
    media: mediaRes.rows,
    feedback: feedbackRes.rows,
    dispatches: dispatchRes.rows
  }
}

export async function listUserReports (userId, query) {
  const { limit, offset, page } = getPagination(query, { limit: 10, page: 1 })
  const res = await db.query(
    `SELECT ${reportFields}
  FROM public.reports r
     WHERE r.user_id = $1
     ORDER BY r.created_at DESC
     LIMIT $2 OFFSET $3`,
    [userId, limit, offset]
  )
  const countRes = await db.query(
    'SELECT COUNT(*) FROM public.reports WHERE user_id = $1',
    [userId]
  )
  const meta = buildPaginationMeta(Number(countRes.rows[0].count), { limit, page })
  return { data: res.rows, meta }
}

export async function getNearbyReports (params) {
  const categoryFilter = params.categories && params.categories.length ? params.categories : null
  const subcategoryFilter = params.subcategories && params.subcategories.length ? params.subcategories : null
  const statusFilter = params.statuses && params.statuses.length ? params.statuses : null

  const result = await db.query(
    'SELECT * FROM public.find_reports_nearby($1, $2, $3, $4, $5, $6, $7, $8)',
    [
      params.latitude,
      params.longitude,
      params.radius,
      categoryFilter,
      subcategoryFilter,
      statusFilter,
      params.limit,
      params.offset
    ]
  )
  return result.rows
}

export async function addFeedback (reportId, userId, { comment }) {
  const res = await db.query(
  `INSERT INTO public.report_feedbacks (report_id, user_id, comment)
     VALUES ($1, $2, $3)
     RETURNING feedback_id, report_id, user_id, comment, created_at`,
  [reportId, userId, comment]
  )
  return res.rows[0]
}

export async function flagReport (reportId, userId, { reason, details }) {
  const res = await db.query(
  `INSERT INTO public.report_flags (report_id, user_id, reason, details)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (report_id, user_id) DO UPDATE SET reason = EXCLUDED.reason, details = EXCLUDED.details
     RETURNING flag_id, report_id, user_id, reason, details, created_at`,
  [reportId, userId, reason, details || null]
  )
  return res.rows[0]
}

export async function updateReportStatus (reportId, { status, priority, notes }, reviewerId) {
  const res = await db.query(
  `UPDATE public.reports
     SET status = COALESCE($2, status),
         priority = COALESCE($3, priority),
         updated_at = NOW(),
         resolved_at = CASE WHEN $2 = 'approved' THEN NOW() ELSE resolved_at END
     WHERE report_id = $1
     RETURNING ${reportFields}`,
  [reportId, status || null, priority || null]
  )
  if (res.rowCount === 0) throw createError(404, 'Report not found')

  if (notes) {
    await db.query(
  `INSERT INTO public.audit_events (table_name, record_id, user_id, action, changes)
       VALUES ('reports', $1::text, $2, 'update', jsonb_build_object('notes', $3))`,
  [reportId, reviewerId || null, notes]
    )
  }

  return res.rows[0]
}

export async function listReportsForAdmin (query) {
  const { limit, offset, page } = getPagination(query, { limit: 20, page: 1 })
  const conditions = []
  const params = []

  if (query.status) {
    params.push(query.status)
    conditions.push(`r.status = $${params.length}`)
  }
  if (query.priority) {
    params.push(query.priority)
    conditions.push(`r.priority = $${params.length}`)
  }
  if (query.categoryId) {
    params.push(Number(query.categoryId))
    conditions.push(`r.category_id = $${params.length}`)
  }
  if (query.city) {
    params.push(query.city)
    conditions.push(`LOWER(r.city) = LOWER($${params.length})`)
  }

  const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : ''

  const sql = `SELECT ${reportFields}, c.name AS category_name, u.full_name AS reporter_name
               FROM public.reports r
               JOIN public.report_categories c ON c.category_id = r.category_id
               JOIN public.users u ON u.user_id = r.user_id
               ${whereClause}
               ORDER BY r.created_at DESC
               LIMIT $${params.length + 1} OFFSET $${params.length + 2}`

  const listRes = await db.query(sql, [...params, limit, offset])

  const countSql = `SELECT COUNT(*) FROM public.reports r ${whereClause}`
  const countRes = await db.query(countSql, params)
  const meta = buildPaginationMeta(Number(countRes.rows[0].count), { limit, page })

  return { data: listRes.rows, meta }
}

export async function updateDispatch (dispatchId, { status, notes }, userId) {
  const res = await db.query(
  `UPDATE public.report_authority_dispatches
     SET status = $2,
         notes = COALESCE($3, notes),
         notified_at = CASE WHEN $2 = 'notified' THEN NOW() ELSE notified_at END,
         acknowledged_at = CASE WHEN $2 = 'acknowledged' THEN NOW() ELSE acknowledged_at END,
         dismissed_at = CASE WHEN $2 = 'dismissed' THEN NOW() ELSE dismissed_at END,
         updated_at = NOW(),
         created_by = COALESCE($4, created_by)
     WHERE dispatch_id = $1
     RETURNING dispatch_id, report_id, authority_id, status, notes, updated_at`,
  [dispatchId, status, notes || null, userId || null]
  )
  if (res.rowCount === 0) throw createError(404, 'Dispatch not found')
  return res.rows[0]
}

export async function getAuthoritiesNear (params) {
  const categoryFilter = params.categoryIds && params.categoryIds.length ? params.categoryIds : null
  const res = await db.query(
    'SELECT * FROM public.find_authorities_nearby($1, $2, $3, $4, $5)',
    [
      params.latitude,
      params.longitude,
      params.radius || 50000,
      categoryFilter,
      params.limit || 20
    ]
  )
  return res.rows
}

import createError from 'http-errors';
import { db, withTransaction } from '../config/db.js';
import { buildPaginationMeta, getPagination } from '../utils/pagination.js';

export async function listUsers(query) {
  const { limit, offset, page } = getPagination(query, { limit: 20, page: 1 });
  const filters = [];
  const params = [];

  if (query.status) {
    params.push(query.status);
    filters.push(`u.account_status = $${params.length}`);
  }
  if (query.role) {
    params.push(query.role);
    filters.push(`u.role = $${params.length}`);
  }
  const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

  const sql = `SELECT u.user_id, u.full_name, u.username, u.email, u.account_status, u.role, u.created_at,
                      (SELECT COUNT(*) FROM civic_app.reports r WHERE r.user_id = u.user_id) AS reports_count,
                      (SELECT COUNT(*) FROM civic_app.report_feedbacks rf WHERE rf.user_id = u.user_id) AS feedback_count
               FROM civic_app.users u
               ${where}
               ORDER BY u.created_at DESC
               LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;

  const listRes = await db.query(sql, [...params, limit, offset]);
  const countRes = await db.query(`SELECT COUNT(*) FROM civic_app.users u ${where}`, params);
  const meta = buildPaginationMeta(Number(countRes.rows[0].count), { limit, page });
  return { data: listRes.rows, meta };
}

export async function updateUserStatus(userId, status) {
  const res = await db.query(
    `UPDATE civic_app.users SET account_status = $2, updated_at = NOW()
     WHERE user_id = $1 RETURNING user_id, account_status`,
    [userId, status]
  );
  if (res.rowCount === 0) throw createError(404, 'User not found');
  return res.rows[0];
}

export async function listPendingVerifications(query) {
  const { limit, offset, page } = getPagination(query, { limit: 20, page: 1 });
  const res = await db.query(
    `SELECT av.verification_id, av.user_id, av.status, av.submitted_at, u.full_name, u.username, u.email
     FROM civic_app.account_verifications av
     JOIN civic_app.users u ON u.user_id = av.user_id
     WHERE av.status = 'pending'
     ORDER BY av.submitted_at ASC
     LIMIT $1 OFFSET $2`,
    [limit, offset]
  );
  const countRes = await db.query(
    `SELECT COUNT(*) FROM civic_app.account_verifications WHERE status = 'pending'`
  );
  const meta = buildPaginationMeta(Number(countRes.rows[0].count), { limit, page });
  return { data: res.rows, meta };
}

export async function reviewVerification(verificationId, reviewerId, { status, rejectionReason, notes }) {
  if (!['approved', 'rejected', 'cancelled'].includes(status)) {
    throw createError(400, 'Invalid status');
  }
  return withTransaction(async (client) => {
    const verificationRes = await client.query(
      `UPDATE civic_app.account_verifications
       SET status = $2, reviewed_at = NOW(), reviewed_by = $3, rejection_reason = $4, notes = $5
       WHERE verification_id = $1 AND status = 'pending'
       RETURNING verification_id, user_id, status, reviewed_at`,
      [verificationId, status, reviewerId || null, rejectionReason || null, notes || null]
    );
    if (verificationRes.rowCount === 0) throw createError(404, 'Verification not found or already reviewed');

    const verification = verificationRes.rows[0];
    const accountStatus = status === 'approved' ? 'verified' : 'suspended';

    await client.query(
      `UPDATE civic_app.users SET account_status = $2 WHERE user_id = $1`,
      [verification.user_id, accountStatus]
    );

    return verification;
  });
}

export async function listAuditEvents(query) {
  const { limit, offset, page } = getPagination(query, { limit: 50, page: 1 });
  const filters = [];
  const params = [];

  if (query.tableName) {
    params.push(query.tableName);
    filters.push(`table_name = $${params.length}`);
  }
  if (query.recordId) {
    params.push(query.recordId);
    filters.push(`record_id = $${params.length}`);
  }

  const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
  const sql = `SELECT audit_id, table_name, record_id, user_id, action, changes, created_at
               FROM civic_app.audit_events
               ${where}
               ORDER BY created_at DESC
               LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;

  const res = await db.query(sql, [...params, limit, offset]);
  const countRes = await db.query(`SELECT COUNT(*) FROM civic_app.audit_events ${where}`, params);
  const meta = buildPaginationMeta(Number(countRes.rows[0].count), { limit, page });
  return { data: res.rows, meta };
}

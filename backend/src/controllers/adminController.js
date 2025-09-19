import {
  listUsers,
  updateUserStatus,
  listPendingVerifications,
  reviewVerification,
  listAuditEvents
} from '../services/adminService.js';

export async function handleListUsers(req, res, next) {
  try {
    const users = await listUsers(req.query);
    res.json(users);
  } catch (error) {
    next(error);
  }
}

export async function handleUpdateUserStatus(req, res, next) {
  try {
    const result = await updateUserStatus(Number(req.params.id), req.body.status);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

export async function handlePendingVerifications(req, res, next) {
  try {
    const result = await listPendingVerifications(req.query);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

export async function handleReviewVerification(req, res, next) {
  try {
    const result = await reviewVerification(Number(req.params.id), req.user.sub, req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

export async function handleAuditEvents(req, res, next) {
  try {
    const events = await listAuditEvents(req.query);
    res.json(events);
  } catch (error) {
    next(error);
  }
}

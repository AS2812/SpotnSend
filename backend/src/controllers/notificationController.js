import {
  listNotifications,
  markNotificationsSeen,
  deleteNotifications,
  sendNotification,
  getNotificationById
} from '../services/notificationService.js';
import { emitUserNotification } from '../sockets/index.js';

export async function handleListNotifications(req, res, next) {
  try {
    const notifications = await listNotifications(req.user.sub, req.query);
    res.json(notifications);
  } catch (error) {
    next(error);
  }
}

export async function handleMarkNotifications(req, res, next) {
  try {
    const result = await markNotificationsSeen(req.user.sub, req.body.ids);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

export async function handleDeleteNotifications(req, res, next) {
  try {
    await deleteNotifications(req.user.sub, req.body.ids);
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}

export async function handleSendNotification(req, res, next) {
  try {
    const notification = await sendNotification(req.body, req.body.channels);
    const io = req.app.get('io');
    if (io) emitUserNotification(io, notification.user_id, notification);
    res.status(201).json(notification);
  } catch (error) {
    next(error);
  }
}

export async function handleGetNotification(req, res, next) {
  try {
    const notification = await getNotificationById(Number(req.params.id), req.user.sub);
    res.json(notification);
  } catch (error) {
    next(error);
  }
}

import {
  createReport,
  getReport,
  listUserReports,
  getNearbyReports,
  addFeedback,
  flagReport,
  updateReportStatus,
  listReportsForAdmin,
  updateDispatch,
  getAuthoritiesNear
} from '../services/reportService.js';

export async function handleCreateReport(req, res, next) {
  try {
    const payload = { ...req.body };
    if (req.files && req.files.length > 0) {
      payload.media = req.files.map((file, index) => ({
        url: file.path,
        kind: file.mimetype.startsWith('video') ? 'video' : 'image',
        isCover: index === 0
      }));
    }
    const report = await createReport(req.user.sub, payload);
    res.status(201).json(report);
  } catch (error) {
    next(error);
  }
}

export async function handleGetReport(req, res, next) {
  try {
    const report = await getReport(Number(req.params.id));
    res.json(report);
  } catch (error) {
    next(error);
  }
}

export async function handleListMyReports(req, res, next) {
  try {
    const reports = await listUserReports(req.user.sub, req.query);
    res.json(reports);
  } catch (error) {
    next(error);
  }
}

export async function handleNearbyReports(req, res, next) {
  try {
    const reports = await getNearbyReports(req.query);
    res.json(reports);
  } catch (error) {
    next(error);
  }
}

export async function handleAddFeedback(req, res, next) {
  try {
    const feedback = await addFeedback(Number(req.params.id), req.user.sub, req.body);
    res.status(201).json(feedback);
  } catch (error) {
    next(error);
  }
}

export async function handleFlagReport(req, res, next) {
  try {
    const flag = await flagReport(Number(req.params.id), req.user.sub, req.body);
    res.status(201).json(flag);
  } catch (error) {
    next(error);
  }
}

export async function handleUpdateReportStatus(req, res, next) {
  try {
    const updated = await updateReportStatus(Number(req.params.id), req.body, req.user.sub);
    res.json(updated);
  } catch (error) {
    next(error);
  }
}

export async function handleAdminReports(req, res, next) {
  try {
    const reports = await listReportsForAdmin(req.query);
    res.json(reports);
  } catch (error) {
    next(error);
  }
}

export async function handleUpdateDispatch(req, res, next) {
  try {
    const dispatch = await updateDispatch(Number(req.params.id), req.body, req.user.sub);
    res.json(dispatch);
  } catch (error) {
    next(error);
  }
}

export async function handleAuthoritiesNearby(req, res, next) {
  try {
    const result = await getAuthoritiesNear(req.query);
    res.json(result);
  } catch (error) {
    next(error);
  }
}

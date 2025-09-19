export function getPagination(query, defaults = { limit: 20, page: 1 }) {
  const limit = Math.min(Number(query.limit) || defaults.limit, 100);
  const page = Math.max(Number(query.page) || defaults.page, 1);
  const offset = (page - 1) * limit;
  return { limit, offset, page };
}

export function buildPaginationMeta(total, { limit, page }) {
  const pageCount = Math.ceil(total / limit) || 1;
  return { total, limit, page, pageCount, hasMore: page < pageCount };
}

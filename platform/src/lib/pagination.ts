/**
 * The envelope every paginated list returns — the same shape as the public
 * discovery endpoints (`{ data, total, page, pageSize }`), so clients can use
 * one pager for all of them.
 */
export interface Page<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
}

export function paginate<T>(data: T[], total: number, page: number, pageSize: number): Page<T> {
  return { data, total, page, pageSize };
}

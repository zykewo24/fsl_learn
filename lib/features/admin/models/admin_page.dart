/// A single page of results plus the totals needed to render pagination.
class AdminPage<T> {
  final List<T> items;

  /// Total number of rows matching the query across all pages.
  final int total;

  /// Zero-based index of this page.
  final int page;

  /// Maximum rows per page.
  final int pageSize;

  const AdminPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// Number of pages needed to show [total] rows. Always at least 1 so the UI
  /// never renders a zero-page pager.
  int get totalPages {
    if (pageSize <= 0) return 1;
    return ((total + pageSize - 1) ~/ pageSize).clamp(1, 1 << 31);
  }

  /// Whether another page exists after this one.
  bool get hasMore => (page + 1) * pageSize < total;

  /// Zero-based index of the first row on this page, for "showing X–Y" text.
  int get firstRowIndex => total == 0 ? 0 : page * pageSize;

  /// One-past-the-last row index on this page, for "showing X–Y" text.
  int get lastRowIndex => firstRowIndex + items.length;
}

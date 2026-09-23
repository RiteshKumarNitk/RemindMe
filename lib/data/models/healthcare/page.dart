import 'json_utils.dart';

/// One page of a backend list endpoint (`{ data, total, page, pageSize }`).
class Page<T> {
  const Page({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;

  static Page<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    return Page<T>(
      items: asMapList(json['data']).map(parse).toList(growable: false),
      total: asInt(json['total']) ?? 0,
      page: asInt(json['page']) ?? 1,
      pageSize: asInt(json['pageSize']) ?? 20,
    );
  }

  static Page<T> empty<T>() =>
      Page<T>(items: const [], total: 0, page: 1, pageSize: 20);
}

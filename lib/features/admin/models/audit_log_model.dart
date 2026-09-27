/// One recorded admin action, read back from the `admin_audit_log` table.
///
/// Rows are inserted by the database trigger in
/// `supabase/admin_roles_and_rls.sql` rather than by the client, so the log
/// cannot be forged or silently dropped by a compromised app build.
class AuditLogModel {
  final String id;

  /// Display name of the admin that performed the action.
  final String actorName;

  /// Email of the admin that performed the action.
  final String actorEmail;

  /// Short verb such as `role.update` or `lesson.create`.
  final String action;

  /// Table the action targeted, e.g. `profiles` or `lessons`.
  final String targetTable;

  /// Primary key of the affected row, when the action targeted one.
  final String? targetId;

  /// Human-readable label for the affected row, e.g. the lesson title.
  final String? targetLabel;

  /// Free-form JSON payload with action-specific detail.
  final Map<String, dynamic> details;

  final DateTime? createdAt;

  const AuditLogModel({
    required this.id,
    required this.actorName,
    required this.actorEmail,
    required this.action,
    required this.targetTable,
    this.targetId,
    this.targetLabel,
    this.details = const <String, dynamic>{},
    this.createdAt,
  });

  factory AuditLogModel.fromMap(Map<String, dynamic> map) {
    return AuditLogModel(
      id: map['id'] as String,
      actorName: (map['actor_name'] as String?) ?? 'Unknown',
      actorEmail: (map['actor_email'] as String?) ?? '',
      action: (map['action'] as String?) ?? 'unknown',
      targetTable: (map['target_table'] as String?) ?? '',
      targetId: map['target_id'] as String?,
      targetLabel: map['target_label'] as String?,
      details: _parseDetails(map['details']),
      createdAt: DateTime.tryParse(
        (map['created_at'] as String?) ?? '',
      )?.toLocal(),
    );
  }

  /// Short `action.targetTable` form used in the log's subtitle.
  String get summary => targetTable.isEmpty ? action : '$action · $targetTable';

  /// Tolerant of `jsonb` arriving as a `String` (some PostgREST versions)
  /// as well as the decoded `Map` it normally is.
  static Map<String, dynamic> _parseDetails(Object? raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.isNotEmpty) {
      // Ignore malformed JSON rather than failing the whole list render.
      return const <String, dynamic>{};
    }
    return const <String, dynamic>{};
  }
}

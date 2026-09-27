/// Normalising PostgREST payloads into plain row maps.
///
/// Separate from `AdminService` so it can be tested directly. The admin area
/// makes a mix of `select()` and `rpc()` calls and PostgREST returns different
/// runtime types for them, which is a bug this file exists to absorb: a
/// function returning `SETOF` may come back as an array or as a bare object for
/// a single row, and an array that came from `rpc()` has the runtime type
/// `List<dynamic>` rather than the `List<Map<String, dynamic>>` that a
/// `PostgrestList` parameter advertises.
///
/// Declaring a parameter as `PostgrestList` and returning it unchanged therefore
/// throws "type `List<dynamic>` is not a subtype of type
/// `List<Map<String, dynamic>>`" at the call boundary, before any code runs. That
/// is what broke the Most Practised Signs list, which is the one admin call
/// that goes through `rpc()` and asks for many rows. Both helpers here take
/// `Object?` and do the conversion themselves, so no caller has to reason about
/// what the decoder produced.
library;

/// [response] as a list of row maps.
///
/// Returns an empty list for null, and for a non-collection payload - an RPC
/// that returned nothing should read as "no rows", not as a crash. Elements
/// that are not maps are dropped rather than throwing, so one malformed row
/// cannot take down a whole list.
List<Map<String, dynamic>> normaliseRows(Object? response) {
  if (response is List) {
    return [
      for (final row in response)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }
  if (response is Map) return [Map<String, dynamic>.from(response)];
  return const [];
}

/// The first row of [response], or null when it holds no rows.
///
/// For functions declared to return a single row, which PostgREST may deliver
/// as a bare object rather than an array.
Map<String, dynamic>? firstRow(Object? response) {
  if (response is Map) return Map<String, dynamic>.from(response);
  if (response is List) {
    for (final row in response) {
      if (row is Map) return Map<String, dynamic>.from(row);
    }
  }
  return null;
}

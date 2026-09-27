import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/features/admin/services/row_payload.dart';

/// Regression tests for the "Most Practised Signs" crash.
///
/// The admin overview threw a type error on its Most Practised Signs section:
/// a `List<dynamic>` is not a `List<Map<String, dynamic>>`. The cause was a
/// helper whose parameter was typed `PostgrestList` and whose body returned the
/// argument unchanged, so the conversion that had to happen was instead
/// demanded of the caller by the runtime - and an `rpc()` result is
/// JSON-decoded, so its runtime type is `List<dynamic>`, not the
/// `List<Map<String, dynamic>>` that `PostgrestList` promises. The mismatch
/// happened before the helper body ran, so no amount of logic inside it could
/// have handled it.
///
/// These tests pin the payload shapes PostgREST actually produces, because the
/// bug was invisible to the type checker: `List<dynamic>` is a perfectly valid
/// argument to a parameter declared as `Object?`.
void main() {
  group('normaliseRows', () {
    test('accepts a JSON-decoded list, which is List<dynamic>', () {
      // This is the exact shape that threw. Built through jsonDecode so the
      // static type is genuinely List<dynamic>, not List<Map<String, dynamic>>.
      final decoded = jsonDecode('''
        [{"sign_id":"a","label":"A","attempts":12}]
      ''');

      expect(decoded, isA<List<dynamic>>());
      expect(
        () => normaliseRows(decoded),
        returnsNormally,
        reason: 'a List<dynamic> must not be rejected by the parameter type',
      );
      expect(normaliseRows(decoded), hasLength(1));
      expect(normaliseRows(decoded).first['label'], 'A');
    });

    test('keeps integer values as integers', () {
      final rows = normaliseRows(jsonDecode('[{"attempts":7}]'));
      expect(rows.single['attempts'], 7);
      expect(rows.single['attempts'], isA<int>());
    });

    test('handles an empty array', () {
      expect(normaliseRows(<dynamic>[]), isEmpty);
    });

    test('wraps a bare map, for a function returning one row', () {
      final rows = normaliseRows({'label': 'A', 'attempts': 1});
      expect(rows, hasLength(1));
      expect(rows.single['label'], 'A');
    });

    test('reads null as no rows rather than throwing', () {
      // An RPC that matched nothing should read as an empty list. Throwing here
      // would turn "no activity yet" into an error state on a fresh install.
      expect(normaliseRows(null), isEmpty);
    });

    test('drops a non-collection payload', () {
      expect(normaliseRows('unexpected'), isEmpty);
      expect(normaliseRows(42), isEmpty);
    });

    test('skips a malformed element instead of failing the list', () {
      // One bad row should not cost the learner the whole ranking.
      final rows = normaliseRows([
        {'label': 'A'},
        'not a row',
        {'label': 'B'},
      ]);
      expect(rows.map((r) => r['label']), ['A', 'B']);
    });

    test('preserves every column of a row', () {
      final rows = normaliseRows([
        {
          'sign_id': 'a',
          'label': 'A',
          'attempts': 12,
          'learners': 3,
        },
      ]);
      expect(
        rows.single.keys,
        containsAll(['sign_id', 'label', 'attempts', 'learners']),
      );
    });
  });

  group('firstRow', () {
    test('reads the first row of an array', () {
      expect(firstRow(jsonDecode('[{"a":1},{"a":2}]'))!['a'], 1);
    });

    test('reads a bare map', () {
      expect(firstRow({'a': 1})!['a'], 1);
    });

    test('returns null for an empty result', () {
      expect(firstRow(<dynamic>[]), isNull);
      expect(firstRow(null), isNull);
    });

    test('skips a leading non-map rather than returning null', () {
      // Returns the first usable row: the shape is "list of things that should
      // be maps", and one stray element is not worth discarding the response.
      expect(firstRow(['junk', {'a': 7}])!['a'], 7);
    });
  });
}

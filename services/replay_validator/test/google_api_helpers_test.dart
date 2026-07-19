import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' as commons;
import 'package:test/test.dart';

import 'package:replay_validator/src/google_api_helpers.dart';

void main() {
  group('isApiConflict', () {
    test('accepts structured Firestore FAILED_PRECONDITION with code 400', () {
      expect(
        isApiConflict(
          commons.DetailedApiRequestError(
            400,
            'stored version does not match required base version',
            jsonResponse: <String, Object?>{
              'error': <String, Object?>{
                'code': 400,
                'message':
                    'stored version does not match required base version',
                'status': 'FAILED_PRECONDITION',
              },
            },
          ),
        ),
        isTrue,
      );
    });

    test('does not classify arbitrary structured code 400 as conflict', () {
      expect(
        isApiConflict(
          commons.DetailedApiRequestError(
            400,
            'invalid document',
            jsonResponse: <String, Object?>{
              'error': <String, Object?>{
                'code': 400,
                'message': 'invalid document',
                'status': 'INVALID_ARGUMENT',
              },
            },
          ),
        ),
        isFalse,
      );
    });

    test('accepts an unstructured Firestore base-version mismatch', () {
      expect(
        isApiConflict(
          commons.DetailedApiRequestError(
            400,
            'the stored version (123) does not match the required base '
            'version (122)',
          ),
        ),
        isTrue,
      );
    });

    test('retains HTTP conflict and precondition status handling', () {
      expect(
        isApiConflict(commons.DetailedApiRequestError(409, 'conflict')),
        isTrue,
      );
      expect(
        isApiConflict(commons.DetailedApiRequestError(412, 'precondition')),
        isTrue,
      );
      expect(
        isApiConflict(commons.DetailedApiRequestError(500, 'server error')),
        isFalse,
      );
    });
  });
}

import 'dart:async';

import 'package:breakbite/data/firebase/firebase_errors.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

FirebaseException _firebase(String code) => FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  group('toAppException', () {
    test('maps Firebase codes to the matching AppException and keeps the cause', () {
      final cases = <String, Type>{
        'unavailable': NetworkException,
        'deadline-exceeded': NetworkException,
        'network-request-failed': NetworkException,
        'permission-denied': PermissionDeniedException,
        'unauthenticated': PermissionDeniedException,
        'not-found': NotFoundException,
        'cancelled': CancelledException,
        'already-exists': ValidationException,
        'invalid-argument': ValidationException,
        'resource-exhausted': ServiceException,
        'internal': ServiceException,
      };
      for (final MapEntry(key: code, value: type) in cases.entries) {
        final error = _firebase(code);
        final mapped = toAppException(error);
        expect(mapped.runtimeType, type, reason: code);
        expect(mapped.cause, same(error), reason: code);
      }
    });

    test('a closed Google account picker is a cancellation, other Google failures are service errors', () {
      const canceled = GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
      const broken = GoogleSignInException(code: GoogleSignInExceptionCode.clientConfigurationError);
      expect(toAppException(canceled), isA<CancelledException>());
      expect(toAppException(broken), isA<ServiceException>());
    });

    test('timeouts are network errors, an AppException passes through, anything else is a service error', () {
      const own = NotFoundException();
      expect(toAppException(TimeoutException('slow')), isA<NetworkException>());
      expect(toAppException(own), same(own));
      expect(toAppException(StateError('bug')), isA<ServiceException>());
    });
  });

  test('guard wraps a value in Ok and a thrown error in Err', () async {
    expect((await guard(() async => 42)).valueOrNull, 42);
    final failed = await guard<int>(() async => throw _firebase('permission-denied'));
    expect(failed.errorOrNull, isA<PermissionDeniedException>());
    expect(failed.errorOrNull?.stackTrace, isNotNull);
  });

  test('guardStream turns stream errors into AppException events', () async {
    final source = Stream<int>.error(_firebase('unavailable'));
    await expectLater(guardStream(source), emitsError(isA<NetworkException>()));
  });

  test('guardStream ends quietly when the rules refuse a listener because the user just signed out', () async {
    final source = Stream<int>.error(_firebase('permission-denied'));
    await expectLater(guardStream(source, signedOut: () => true), emitsDone);
  });

  test('guardStream still reports a refused listener while the user is signed in', () async {
    final source = Stream<int>.error(_firebase('permission-denied'));
    await expectLater(guardStream(source, signedOut: () => false), emitsError(isA<PermissionDeniedException>()));
  });
}

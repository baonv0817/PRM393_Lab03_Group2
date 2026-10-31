import 'package:breakbite/data/services/services.dart';

class FakeCrashService implements CrashService {
  final errors = <Object>[];
  final keys = <String, Object>{};

  @override
  void forceTestCrash() => throw StateError('Test crash (dev)');

  @override
  Future<void> recordError(Object error, StackTrace? stack, {String? reason}) async => errors.add(error);

  @override
  Future<void> setKey(String key, Object value) async => keys[key] = value;

  @override
  Future<void> setUserId(String uid) async => keys['uid'] = uid;
}

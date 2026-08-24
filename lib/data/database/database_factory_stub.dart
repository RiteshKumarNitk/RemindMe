import 'package:sqflite/sqflite.dart' show DatabaseFactory;

/// Compile-time stand-in for the web FFI factory on non-web platforms. Never
/// executed: the kIsWeb branch in [AppDatabase] prevents this from running.
DatabaseFactory get databaseFactoryFfiWeb =>
    throw UnimplementedError('web-only factory');

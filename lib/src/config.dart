import 'dart:io';

import 'package:postgres/postgres.dart';

class DbConfig {
  DbConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.sslMode,
  });

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final SslMode sslMode;

  factory DbConfig.fromEnv() {
    return DbConfig(
      host: _env('PGHOST'),
      port: int.parse(_env('PGPORT', fallback: '5432')),
      database: _env('PGDATABASE'),
      username: _env('PGUSER'),
      password: _env('PGPASSWORD'),
      sslMode: _parseSslMode(_env('PGSSLMODE', fallback: 'require')),
    );
  }
}

String _env(String key, {String? fallback}) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) {
    if (fallback != null) {
      return fallback;
    }
    throw StateError('Missing required environment variable: $key');
  }
  return value;
}

SslMode _parseSslMode(String value) {
  switch (value.toLowerCase()) {
    case 'disable':
      return SslMode.disable;
    case 'require':
      return SslMode.require;
    case 'verify-full':
      return SslMode.verifyFull;
    default:
      return SslMode.require;
  }
}

import 'package:postgres/postgres.dart';

import 'config.dart';
import 'formatters.dart';

class AppealRecord {
  AppealRecord({
    required this.id,
    required this.scholarName,
    required this.awardProgram,
    required this.appealReason,
    required this.appealAmount,
    required this.status,
    required this.submittedOn,
    required this.owner,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String scholarName;
  final String awardProgram;
  final String appealReason;
  final num appealAmount;
  final String status;
  final DateTime submittedOn;
  final String? owner;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class AppealSummary {
  AppealSummary({
    required this.status,
    required this.count,
    required this.totalAmount,
  });

  final String status;
  final int count;
  final num totalAmount;
}

class AppealStore {
  AppealStore(this._connection);

  final Connection _connection;

  static Future<AppealStore> connect(DbConfig config) async {
    final connection = await Connection.open(
      Endpoint(
        host: config.host,
        port: config.port,
        database: config.database,
        username: config.username,
        password: config.password,
      ),
      settings: ConnectionSettings(sslMode: config.sslMode),
    );
    return AppealStore(connection);
  }

  Future<AppealRecord> create({
    required String scholarName,
    required String awardProgram,
    required String appealReason,
    required num appealAmount,
    required String status,
    required DateTime submittedOn,
    String? owner,
    String? notes,
  }) async {
    final sql = Sql.named('''
      insert into groupscholar_award_appeal_tracker.appeals (
        scholar_name,
        award_program,
        appeal_reason,
        appeal_amount,
        status,
        submitted_on,
        owner,
        notes
      ) values (
        @scholar_name,
        @award_program,
        @appeal_reason,
        @appeal_amount,
        @status,
        @submitted_on,
        @owner,
        @notes
      )
      returning
        id,
        scholar_name,
        award_program,
        appeal_reason,
        appeal_amount,
        status,
        submitted_on,
        owner,
        notes,
        created_at,
        updated_at
    ''');
    final result = await _connection.execute(sql, parameters: {
      'scholar_name': scholarName,
      'award_program': awardProgram,
      'appeal_reason': appealReason,
      'appeal_amount': appealAmount,
      'status': normalizeStatus(status),
      'submitted_on': submittedOn,
      'owner': owner,
      'notes': notes,
    });

    return _mapRecord(result.first);
  }

  Future<List<AppealRecord>> list({String? status}) async {
    final sql = Sql.named('''
      select
        id,
        scholar_name,
        award_program,
        appeal_reason,
        appeal_amount,
        status,
        submitted_on,
        owner,
        notes,
        created_at,
        updated_at
      from groupscholar_award_appeal_tracker.appeals
      where (@status is null or status = @status)
      order by submitted_on desc, created_at desc
    ''');
    final result = await _connection.execute(sql, parameters: {
      'status': status == null ? null : normalizeStatus(status),
    });
    return result.map(_mapRecord).toList();
  }

  Future<AppealRecord?> updateStatus({
    required String id,
    required String status,
    String? notes,
  }) async {
    final sql = Sql.named('''
      update groupscholar_award_appeal_tracker.appeals
      set status = @status,
          notes = coalesce(@notes, notes),
          updated_at = now()
      where id = @id
      returning
        id,
        scholar_name,
        award_program,
        appeal_reason,
        appeal_amount,
        status,
        submitted_on,
        owner,
        notes,
        created_at,
        updated_at
    ''');
    final result = await _connection.execute(sql, parameters: {
      'id': id,
      'status': normalizeStatus(status),
      'notes': notes,
    });

    if (result.isEmpty) {
      return null;
    }
    return _mapRecord(result.first);
  }

  Future<List<AppealSummary>> summary() async {
    final sql = Sql.named('''
      select
        status,
        count(*) as appeal_count,
        coalesce(sum(appeal_amount), 0) as total_amount
      from groupscholar_award_appeal_tracker.appeals
      group by status
      order by appeal_count desc
    ''');
    final result = await _connection.execute(sql);
    return result
        .map(
          (row) => AppealSummary(
            status: row[0] as String,
            count: (row[1] as int),
            totalAmount: row[2] as num,
          ),
        )
        .toList();
  }

  Future<void> close() async {
    await _connection.close();
  }

  AppealRecord _mapRecord(ResultRow row) {
    return AppealRecord(
      id: row[0] as String,
      scholarName: row[1] as String,
      awardProgram: row[2] as String,
      appealReason: row[3] as String,
      appealAmount: row[4] as num,
      status: row[5] as String,
      submittedOn: row[6] as DateTime,
      owner: row[7] as String?,
      notes: row[8] as String?,
      createdAt: row[9] as DateTime,
      updatedAt: row[10] as DateTime,
    );
  }
}

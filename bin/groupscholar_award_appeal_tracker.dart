import 'dart:io';

import 'package:args/args.dart';
import 'package:groupscholar_award_appeal_tracker/groupscholar_award_appeal_tracker.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand('add')
    ..addCommand('list')
    ..addCommand('update-status')
    ..addCommand('aging')
    ..addCommand('backlog')
    ..addCommand('summary')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');

  final addCommand = parser.commands['add']!;
  addCommand
    ..addOption('scholar', help: 'Scholar name.', valueHelp: 'NAME')
    ..addOption('program', help: 'Award program.', valueHelp: 'PROGRAM')
    ..addOption('reason', help: 'Appeal reason.', valueHelp: 'TEXT')
    ..addOption('amount', help: 'Appeal amount.', valueHelp: 'AMOUNT')
    ..addOption('status', help: 'Appeal status.', defaultsTo: 'pending')
    ..addOption('submitted-on', help: 'Submitted date.', valueHelp: 'YYYY-MM-DD')
    ..addOption('owner', help: 'Owner handling the appeal.')
    ..addOption('notes', help: 'Optional notes.');

  final listCommand = parser.commands['list']!;
  listCommand.addOption('status', help: 'Filter by status.');

  final updateCommand = parser.commands['update-status']!;
  updateCommand
    ..addOption('id', help: 'Appeal id.', valueHelp: 'UUID')
    ..addOption('status', help: 'New status.', valueHelp: 'STATUS')
    ..addOption('notes', help: 'Append notes for context.');

  final agingCommand = parser.commands['aging']!;
  agingCommand
    ..addOption('status', help: 'Filter by status.')
    ..addOption(
      'min-days',
      help: 'Minimum days since submission.',
      defaultsTo: '14',
    )
    ..addFlag(
      'include-closed',
      help: 'Include approved/denied/withdrawn appeals.',
      negatable: false,
    );

  final backlogCommand = parser.commands['backlog']!;
  backlogCommand
    ..addOption('status', help: 'Filter by status.')
    ..addOption('as-of', help: 'Report date.', valueHelp: 'YYYY-MM-DD')
    ..addFlag(
      'include-closed',
      help: 'Include approved/denied/withdrawn appeals.',
      negatable: false,
    );

  try {
    final parsed = parser.parse(args);
    if (parsed['help'] as bool || parsed.command == null) {
      _printUsage(parser);
      exit(0);
    }

    final config = DbConfig.fromEnv();
    final store = await AppealStore.connect(config);

    try {
      switch (parsed.command!.name) {
        case 'add':
          await _handleAdd(store, parsed.command!);
          break;
        case 'list':
          await _handleList(store, parsed.command!);
          break;
        case 'update-status':
          await _handleUpdateStatus(store, parsed.command!);
          break;
        case 'aging':
          await _handleAging(store, parsed.command!);
          break;
        case 'backlog':
          await _handleBacklog(store, parsed.command!);
          break;
        case 'summary':
          await _handleSummary(store);
          break;
      }
    } finally {
      await store.close();
    }
  } on FormatException catch (error) {
    stderr.writeln('Error: ${error.message}');
    _printUsage(parser);
    exit(64);
  } on StateError catch (error) {
    stderr.writeln('Error: ${error.message}');
    exit(64);
  } on ArgumentError catch (error) {
    stderr.writeln('Error: ${error.message}');
    exit(64);
  }
}

Future<void> _handleAdd(AppealStore store, ArgResults command) async {
  final scholar = command['scholar'] as String?;
  final program = command['program'] as String?;
  final reason = command['reason'] as String?;
  final amountRaw = command['amount'] as String?;
  if (scholar == null || program == null || reason == null || amountRaw == null) {
    throw FormatException('Missing required arguments for add.');
  }

  final amount = num.parse(amountRaw);
  final submittedOnRaw = command['submitted-on'] as String?;
  final submittedOn = submittedOnRaw == null
      ? DateTime.now()
      : DateTime.parse(submittedOnRaw);

  final record = await store.create(
    scholarName: scholar,
    awardProgram: program,
    appealReason: reason,
    appealAmount: amount,
    status: command['status'] as String,
    submittedOn: submittedOn,
    owner: command['owner'] as String?,
    notes: command['notes'] as String?,
  );

  stdout.writeln('Appeal logged:');
  stdout.writeln('  ID: ${record.id}');
  stdout.writeln('  Scholar: ${record.scholarName}');
  stdout.writeln('  Status: ${record.status}');
  stdout.writeln('  Amount: ${formatCurrency(record.appealAmount)}');
  stdout.writeln('  Submitted: ${formatDate(record.submittedOn)}');
}

Future<void> _handleList(AppealStore store, ArgResults command) async {
  final status = command['status'] as String?;
  final records = await store.list(status: status);
  if (records.isEmpty) {
    stdout.writeln('No appeals found.');
    return;
  }

  final headers = [
    'ID',
    'Scholar',
    'Program',
    'Status',
    'Amount',
    'Submitted',
    'Owner'
  ];
  final rows = records
      .map(
        (record) => [
          record.id,
          record.scholarName,
          record.awardProgram,
          record.status,
          formatCurrency(record.appealAmount),
          formatDate(record.submittedOn),
          record.owner ?? '-'
        ],
      )
      .toList();

  stdout.writeln(renderTable(headers, rows));
}

Future<void> _handleUpdateStatus(AppealStore store, ArgResults command) async {
  final id = command['id'] as String?;
  final status = command['status'] as String?;
  if (id == null || status == null) {
    throw FormatException('Missing required arguments for update-status.');
  }

  final record = await store.updateStatus(
    id: id,
    status: status,
    notes: command['notes'] as String?,
  );
  if (record == null) {
    stdout.writeln('No appeal found for id $id.');
    return;
  }

  stdout.writeln('Updated ${record.id} -> ${record.status}');
}

Future<void> _handleSummary(AppealStore store) async {
  final summary = await store.summary();
  if (summary.isEmpty) {
    stdout.writeln('No appeals tracked yet.');
    return;
  }

  final headers = ['Status', 'Count', 'Total Amount'];
  final rows = summary
      .map(
        (row) => [
          row.status,
          row.count.toString(),
          formatCurrency(row.totalAmount),
        ],
      )
      .toList();
  stdout.writeln(renderTable(headers, rows));
}

Future<void> _handleAging(AppealStore store, ArgResults command) async {
  final status = command['status'] as String?;
  final minDaysRaw = command['min-days'] as String?;
  if (minDaysRaw == null || minDaysRaw.trim().isEmpty) {
    throw FormatException('Missing required value for min-days.');
  }
  final minDays = int.parse(minDaysRaw);
  final includeClosed = command['include-closed'] as bool;

  final records = await store.list(status: status);
  final now = DateTime.now();
  final closedStatuses = {'approved', 'denied', 'withdrawn'};

  final aging = records
      .where(
        (record) =>
            includeClosed ||
            status != null ||
            !closedStatuses.contains(record.status),
      )
      .map((record) => (record: record, daysOpen: daysBetween(record.submittedOn, now)))
      .where((entry) => entry.daysOpen >= minDays)
      .toList()
    ..sort((a, b) => b.daysOpen.compareTo(a.daysOpen));

  if (aging.isEmpty) {
    stdout.writeln('No appeals meet the aging criteria.');
    return;
  }

  final headers = [
    'ID',
    'Scholar',
    'Status',
    'Days Open',
    'Amount',
    'Submitted',
    'Owner'
  ];
  final rows = aging
      .map(
        (entry) => [
          entry.record.id,
          entry.record.scholarName,
          entry.record.status,
          entry.daysOpen.toString(),
          formatCurrency(entry.record.appealAmount),
          formatDate(entry.record.submittedOn),
          entry.record.owner ?? '-'
        ],
      )
      .toList();

  stdout.writeln(renderTable(headers, rows));
}

Future<void> _handleBacklog(AppealStore store, ArgResults command) async {
  final status = command['status'] as String?;
  final includeClosed = command['include-closed'] as bool;
  final asOfRaw = command['as-of'] as String?;
  final asOf = asOfRaw == null ? DateTime.now() : DateTime.parse(asOfRaw);

  final records = await store.list(status: status);
  final closedStatuses = {'approved', 'denied', 'withdrawn'};
  final bucketOrder = ['0-7', '8-14', '15-30', '31-60', '61+'];
  final totals = <String, (int count, num amount)>{};

  for (final record in records) {
    if (!includeClosed &&
        status == null &&
        closedStatuses.contains(record.status)) {
      continue;
    }
    final daysOpen = daysBetween(record.submittedOn, asOf);
    final bucket = ageBucketForDays(daysOpen);
    final current = totals[bucket];
    if (current == null) {
      totals[bucket] = (1, record.appealAmount);
    } else {
      totals[bucket] = (current.$1 + 1, current.$2 + record.appealAmount);
    }
  }

  final rows = <List<String>>[];
  for (final bucket in bucketOrder) {
    final data = totals[bucket];
    if (data == null) {
      continue;
    }
    rows.add([
      bucket,
      data.$1.toString(),
      formatCurrency(data.$2),
    ]);
  }

  if (rows.isEmpty) {
    stdout.writeln('No appeals meet the backlog criteria.');
    return;
  }

  final headers = ['Age Bucket (Days)', 'Count', 'Total Amount'];
  stdout.writeln(renderTable(headers, rows));
}

void _printUsage(ArgParser parser) {
  stdout.writeln('Group Scholar Award Appeal Tracker');
  stdout.writeln('');
  stdout.writeln('Usage:');
  stdout.writeln('  dart run bin/groupscholar_award_appeal_tracker.dart <command> [options]');
  stdout.writeln('');
  stdout.writeln('Commands:');
  stdout.writeln('  add           Log a new appeal.');
  stdout.writeln('  list          List appeals (optionally filtered by status).');
  stdout.writeln('  update-status Update appeal status.');
  stdout.writeln('  aging         Show open appeals over a minimum age.');
  stdout.writeln('  backlog       Summarize open appeals by aging bucket.');
  stdout.writeln('  summary       Show counts and totals by status.');
  stdout.writeln('');
  stdout.writeln(parser.usage);
}

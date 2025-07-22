import 'dart:io';

import 'package:args/args.dart';
import 'package:groupscholar_award_appeal_tracker/groupscholar_award_appeal_tracker.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand('add')
    ..addCommand('list')
    ..addCommand('update-status')
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
  stdout.writeln('  summary       Show counts and totals by status.');
  stdout.writeln('');
  stdout.writeln(parser.usage);
}

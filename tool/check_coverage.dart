// Fails the build when line coverage drops below a threshold.
//
// `package:test` has no built-in gate the way Vitest does, so CI runs
// `dart run coverage:test_with_coverage` and then this script over the lcov it
// writes.
//
// Usage: dart run tool/check_coverage.dart [threshold] [path/to/lcov.info]
import 'dart:io';

/// Files with no logic worth measuring: the public barrel is re-exports only,
/// and the version constant is a single literal kept in step with pubspec.yaml.
const Set<String> excluded = {
  'lib/supdesk.dart',
  'lib/src/version.dart',
};

void main(List<String> args) {
  final threshold = double.tryParse(args.isEmpty ? '80' : args.first) ?? 80;
  final path = args.length > 1 ? args[1] : 'coverage/lcov.info';

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln(
      'No coverage report at $path. Run `dart run coverage:test_with_coverage` '
      'first.',
    );
    exit(1);
  }

  final files = _parse(file.readAsLinesSync());
  if (files.isEmpty) {
    stderr.writeln('$path contained no coverage records.');
    exit(1);
  }

  var totalFound = 0;
  var totalHit = 0;
  final rows = <_Row>[];

  for (final entry in files.entries) {
    if (excluded.contains(entry.key)) continue;

    totalFound += entry.value.found;
    totalHit += entry.value.hit;
    rows.add(_Row(entry.key, entry.value.hit, entry.value.found));
  }

  rows.sort((a, b) => a.percent.compareTo(b.percent));

  final width =
      rows.fold(0, (w, row) => row.path.length > w ? row.path.length : w);
  for (final row in rows) {
    stdout.writeln(
      '${row.path.padRight(width)}  '
      '${row.percent.toStringAsFixed(1).padLeft(5)}%  '
      '(${row.hit}/${row.found})',
    );
  }

  final total = totalFound == 0 ? 0.0 : totalHit / totalFound * 100;
  stdout.writeln('-' * (width + 18));
  stdout.writeln(
    '${'TOTAL'.padRight(width)}  ${total.toStringAsFixed(1).padLeft(5)}%  '
    '($totalHit/$totalFound)',
  );

  if (total + 1e-9 < threshold) {
    stderr.writeln(
      '\nCoverage ${total.toStringAsFixed(1)}% is below the '
      '${threshold.toStringAsFixed(0)}% threshold.',
    );
    exit(1);
  }

  stdout.writeln(
    '\nCoverage ${total.toStringAsFixed(1)}% meets the '
    '${threshold.toStringAsFixed(0)}% threshold.',
  );
}

Map<String, _Counts> _parse(List<String> lines) {
  final files = <String, _Counts>{};
  String? current;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll(r'\', '/');
      final index = current.indexOf('lib/');
      if (index > 0) current = current.substring(index);
      files.putIfAbsent(current, _Counts.new);
      continue;
    }

    if (current == null || !line.startsWith('DA:')) continue;

    final parts = line.substring(3).split(',');
    if (parts.length < 2) continue;

    final counts = files[current]!;
    counts.found++;
    if ((int.tryParse(parts[1]) ?? 0) > 0) counts.hit++;
  }

  return files;
}

class _Counts {
  int found = 0;
  int hit = 0;
}

class _Row {
  _Row(this.path, this.hit, this.found);

  final String path;
  final int hit;
  final int found;

  double get percent => found == 0 ? 100 : hit / found * 100;
}

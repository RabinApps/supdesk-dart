// Fails the build when `lib/src/version.dart` drifts from `pubspec.yaml`.
//
// The version travels in the `user-agent` of every request, so a stale constant
// silently mislabels traffic. CI checks this before publishing; the release
// workflow additionally checks the git tag against pubspec.
//
// Usage: dart run tool/check_version.dart [expected-version]
import 'dart:io';

void main(List<String> args) {
  final pubspec = _pubspecVersion();
  final source = _sourceVersion();

  if (pubspec != source) {
    stderr.writeln(
      'Version mismatch: pubspec.yaml is $pubspec but lib/src/version.dart is '
      '$source.',
    );
    exit(1);
  }

  if (args.isNotEmpty && args.first != pubspec) {
    stderr.writeln(
      'Version mismatch: expected ${args.first} but pubspec.yaml is $pubspec.',
    );
    exit(1);
  }

  stdout.writeln('Version $pubspec is consistent.');
}

String _pubspecVersion() {
  final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
      .firstMatch(File('pubspec.yaml').readAsStringSync());

  if (match == null) {
    stderr.writeln('Could not find a version in pubspec.yaml.');
    exit(1);
  }

  return match.group(1)!;
}

String _sourceVersion() {
  final match = RegExp("packageVersion\\s*=\\s*'([^']+)'")
      .firstMatch(File('lib/src/version.dart').readAsStringSync());

  if (match == null) {
    stderr.writeln('Could not find packageVersion in lib/src/version.dart.');
    exit(1);
  }

  return match.group(1)!;
}

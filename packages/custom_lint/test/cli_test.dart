import 'package:test/test.dart';

import '../bin/custom_lint.dart' as cli;
import 'create_project.dart';
import 'mock_fs.dart';

void main() {
  test('CLI lists warnings from all plugins and set exit code', () async {
    final plugin = createPlugin(
      name: 'test_lint',
      main: '''
import 'dart:isolate';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' hide Element;
import 'package:custom_lint_builder/custom_lint_builder.dart';

void main(List<String> args, SendPort sendPort) {
  startPlugin(sendPort, _HelloWorldLint());
}

class _HelloWorldLint extends PluginBase {
  @override
  Iterable<AnalysisError> getLints(LibraryElement library) sync* {
    final libraryPath = library.source.fullName;
    yield AnalysisError(
      AnalysisErrorSeverity.WARNING,
      AnalysisErrorType.LINT,
      Location(libraryPath, 0, 0, 0, 0),
      'Hello world',
      'hello_world',
    );
  }
}
''',
    );
    final plugin2 = createPlugin(
      name: 'test_lint2',
      main: '''
import 'dart:isolate';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' hide Element;
import 'package:custom_lint_builder/custom_lint_builder.dart';

void main(List<String> args, SendPort sendPort) {
  startPlugin(sendPort, _AnotherLint());
}

class _AnotherLint extends PluginBase {
  @override
  Iterable<AnalysisError> getLints(LibraryElement library) sync* {
    final libraryPath = library.source.fullName;
    yield AnalysisError(
      AnalysisErrorSeverity.WARNING,
      AnalysisErrorType.LINT,
      Location(libraryPath, 0, 0, 1, 42),
      'Oy',
      'oy',
    );
  }
}
''',
    );

    final app = creatLintUsage(
      source: {
        'lib/main.dart': '''
void fn() {}
''',
        'lib/another.dart': '''
void fail() {}
''',
      },
      plugins: {'test_lint': plugin.uri, 'test_lint2': plugin2.uri},
      name: 'test_app',
    );

    await runWithIOOverride(
      (out, err) async {
        final code = await cli.main();

        expect(code, -1);
        expect(out.join(), completion('''
  lib/another.dart:0:0 • Hello world • hello_world
  lib/another.dart:1:42 • Oy • oy
  lib/main.dart:0:0 • Hello world • hello_world
  lib/main.dart:1:42 • Oy • oy
'''));
        expect(err, emitsDone);
      },
      currentDirectory: app,
    );
  });

  test('supports plugins that do not compile', () async {
    final plugin = createPlugin(
      name: 'test_lint',
      main: '''
import 'dart:isolate';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' hide Element;
import 'package:custom_lint_builder/custom_lint_builder.dart';

void main(List<String> args, SendPort sendPort) {
  startPlugin(sendPort, _HelloWorldLint());
}

class _HelloWorldLint extends PluginBase {
  @override
  Iterable<AnalysisError> getLints(LibraryElement library) sync* {
    final libraryPath = library.source.fullName;
    yield AnalysisError(
      AnalysisErrorSeverity.WARNING,
      AnalysisErrorType.LINT,
      Location(libraryPath, 0, 0, 0, 0),
      'Hello world',
      'hello_world',
    );
  }
}
''',
    );
    final plugin2 = createPlugin(
      name: 'test_lint2',
      main: '''
int x = 'oy';
''',
    );

    final app = creatLintUsage(
      source: {
        'lib/main.dart': '''
void fn() {}
''',
        'lib/another.dart': '''
void fail() {}
''',
      },
      plugins: {'test_lint': plugin.uri, 'test_lint2': plugin2.uri},
      name: 'test_app',
    );

    await runWithIOOverride(
      (out, err) async {
        final code = await cli.main();

        expect(code, -1);
        expect(
          out.join(),
          completion(
            '''
IsolateSpawnException: Unable to spawn isolate: ${plugin2.path}/lib/main.dart:1:9: \x1B[31mError: A value of type 'String' can't be assigned to a variable of type 'int'.\x1B[39;49m
int x = 'oy';
        ^
  lib/another.dart:0:0 • Hello world • hello_world
  lib/main.dart:0:0 • Hello world • hello_world
''',
          ),
        );
        expect(err, emitsDone);
      },
      currentDirectory: app,
    );
  });

  test('Shows prints and exceptions', () async {
    final plugin = createPlugin(
      name: 'test_lint',
      main: r'''
import 'dart:isolate';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' hide Element;
import 'package:custom_lint_builder/custom_lint_builder.dart';

void main(List<String> args, SendPort sendPort) {
  startPlugin(sendPort, _HelloWorldLint());
}

class _HelloWorldLint extends PluginBase {
  @override
  Iterable<AnalysisError> getLints(LibraryElement library) sync* {
    final libraryPath = library.source.fullName;
    if (library.topLevelElements.single.name == 'fail') {
      print('');
      print(' ');
       print('Hello\nworld');
       throw StateError('fail');
    }
    yield AnalysisError(
      AnalysisErrorSeverity.WARNING,
      AnalysisErrorType.LINT,
      Location(libraryPath, 0, 0, 0, 0),
      'Hello world',
      'hello_world',
    );
  }
}
''',
    );

    final plugin2 = createPlugin(
      name: 'test_lint2',
      main: '''
import 'dart:isolate';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' hide Element;
import 'package:custom_lint_builder/custom_lint_builder.dart';

void main(List<String> args, SendPort sendPort) {
  startPlugin(sendPort, _AnotherLint());
}

class _AnotherLint extends PluginBase {
  @override
  Iterable<AnalysisError> getLints(LibraryElement library) sync* {
    final libraryPath = library.source.fullName;
    yield AnalysisError(
      AnalysisErrorSeverity.WARNING,
      AnalysisErrorType.LINT,
      Location(libraryPath, 0, 0, 1, 42),
      'Oy',
      'oy',
    );
  }
}
''',
    );

    final app = creatLintUsage(
      source: {
        'lib/main.dart': '''
void fn() {}
''',
        'lib/another.dart': '''
void fail() {}
''',
      },
      plugins: {'test_lint': plugin.uri, 'test_lint2': plugin2.uri},
      name: 'test_app',
    );

    await runWithIOOverride(
      (out, err) async {
        final code = await cli.main();

        expect(code, -1);
        expect(
          out.join(),
          completion(
            allOf(
              contains('''
[test_lint]
[test_lint]  
[test_lint] Hello
[test_lint] world
Bad state: fail
#0      _HelloWorldLint.getLints (package:test_lint/main.dart:18:8)
'''),
              endsWith(
                '''
  lib/another.dart:1:42 • Oy • oy
  lib/main.dart:0:0 • Hello world • hello_world
  lib/main.dart:1:42 • Oy • oy
''',
              ),
            ),
          ),
        );
        expect(err, emitsDone);
      },
      currentDirectory: app,
    );
  });
}

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class Module {
  Module(this.directory, this.manifest, this.contract);

  final Directory directory;
  final YamlMap manifest;
  final YamlMap contract;
  String get name => manifest['name'] as String;
  String get role => contract['role'] as String;
  Set<String> get dependencies => {
    ...?(manifest['dependencies'] as YamlMap?)?.keys.cast<String>(),
  };
  Set<String> get allowed => {
    ...?(contract['allowed_dependencies'] as YamlList?)?.cast<String>(),
  };
}

// Prune generated and tool-owned trees before descending, and never follow links.
Iterable<Directory> _sourceDirectories(Directory parent) sync* {
  const excluded = {'.dart_tool', 'build', '.git', '.fvm'};
  for (final child
      in parent.listSync(followLinks: false).whereType<Directory>()) {
    if (excluded.contains(p.basename(child.path))) continue;
    yield child;
    yield* _sourceDirectories(child);
  }
}

// Workspace members must be explicit paths; glob expansion is not supported.
List<String> checkArchitecture(Directory root) {
  final errors = <String>[];
  final manifest =
      loadYaml(File(p.join(root.path, 'pubspec.yaml')).readAsStringSync())
          as YamlMap;
  final members = (manifest['workspace'] as YamlList? ?? YamlList())
      .cast<String>();
  final modules = <String, Module>{};
  final memberPaths = <String>{};
  for (final member in members) {
    final directory = Directory(p.normalize(p.join(root.path, member)));
    memberPaths.add(directory.path);
    final pubspec = File(p.join(directory.path, 'pubspec.yaml'));
    final metadata = File(p.join(directory.path, 'module.yaml'));
    if (!pubspec.existsSync() || !metadata.existsSync()) {
      errors.add('$member: missing pubspec.yaml or module.yaml');
      continue;
    }
    final module = Module(
      directory,
      loadYaml(pubspec.readAsStringSync()) as YamlMap,
      loadYaml(metadata.readAsStringSync()) as YamlMap,
    );
    if (modules.containsKey(module.name)) {
      errors.add('${module.name}: duplicate module name');
    }
    modules[module.name] = module;
    if (module.manifest['resolution'] != 'workspace') {
      errors.add('${module.name}: resolution must be workspace');
    }
    if (!{
      'shell',
      'catalog',
      'feature',
      'capability',
      'ui',
      'foundation',
    }.contains(module.role)) {
      errors.add('${module.name}: unknown role');
    }
    if ((module.contract['responsibility'] as String? ?? '').trim().isEmpty) {
      errors.add('${module.name}: missing responsibility');
    }
    if (module.contract['storage'] == null) {
      errors.add('${module.name}: declare storage ownership or none');
    }
  }
  for (final category in ['apps', 'features', 'packages']) {
    final parent = Directory(p.join(root.path, category));
    if (FileSystemEntity.typeSync(parent.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      continue;
    }
    for (final child in _sourceDirectories(parent)) {
      if (File(p.join(child.path, 'pubspec.yaml')).existsSync() &&
          !memberPaths.contains(p.normalize(child.path))) {
        errors.add('${child.path}: package missing from workspace');
      }
    }
  }
  for (final module in modules.values) {
    for (final allowed in module.allowed) {
      if (!modules.containsKey(allowed)) {
        errors.add(
          '${module.name}: allowed dependency $allowed does not exist',
        );
      }
    }
    for (final name in module.dependencies.where(modules.containsKey)) {
      final target = modules[name]!;
      if (!module.allowed.contains(name)) {
        errors.add('${module.name}: dependency on $name is not allowed');
      }
      if (target.role == 'shell' || target.role == 'catalog') {
        errors.add('${module.name}: cannot depend on an application');
      }
      if (module.role != 'shell' &&
          module.role != 'catalog' &&
          target.role == 'feature') {
        errors.add(
          '${module.name}: feature-to-feature or lower-layer-to-feature dependency',
        );
      }
      if (module.role == 'ui' && !{'foundation', 'ui'}.contains(target.role)) {
        errors.add('${module.name}: UI kit cannot depend on business modules');
      }
    }
    final lib = Directory(p.join(module.directory.path, 'lib'));
    if (!lib.existsSync()) continue;
    for (final file
        in lib
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final unit = parseString(
        content: file.readAsStringSync(),
        path: file.path,
      ).unit;
      for (final directive in unit.directives) {
        final uris = <String?>[];
        if (directive is UriBasedDirective) uris.add(directive.uri.stringValue);
        if (directive is ImportDirective) {
          uris.addAll(directive.configurations.map((c) => c.uri.stringValue));
        }
        if (directive is ExportDirective) {
          uris.addAll(directive.configurations.map((c) => c.uri.stringValue));
        }
        for (final value in uris.whereType<String>()) {
          final uri = Uri.parse(value);
          final relative = p.relative(file.path, from: root.path);
          if (uri.scheme == 'package') {
            final target = uri.pathSegments.first;
            if (target != module.name &&
                !module.dependencies.contains(target)) {
              errors.add('$relative: undeclared runtime dependency $target');
            }
            if (target != module.name &&
                uri.pathSegments.skip(1).contains('src')) {
              errors.add('$relative: private import $value');
            }
            if (module.role == 'feature' &&
                (value == 'package:flutter/material.dart' ||
                    value == 'package:flutter/cupertino.dart' ||
                    {'material', 'cupertino'}.contains(target))) {
              errors.add('$relative: compose visual components through ui_kit');
            }
          } else if (uri.scheme.isEmpty) {
            final resolved = p.normalize(p.join(p.dirname(file.path), value));
            if (!p.isWithin(lib.path, resolved)) {
              errors.add('$relative: relative import escapes module lib');
            }
          } else if (uri.scheme != 'dart') {
            errors.add('$relative: unsupported import scheme ${uri.scheme}');
          }
        }
      }
    }
  }
  final active = <String>{};
  final done = <String>{};
  void visit(String name) {
    if (active.contains(name)) {
      errors.add('Dependency cycle through $name');
      return;
    }
    if (!done.add(name)) return;
    active.add(name);
    for (final dependency in modules[name]!.dependencies.where(
      modules.containsKey,
    )) {
      visit(dependency);
    }
    active.remove(name);
  }

  for (final name in modules.keys) {
    visit(name);
  }
  return errors;
}

void main(List<String> args) {
  final errors = checkArchitecture(Directory.current);
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
  } else {
    stdout.writeln('Module boundaries verified.');
  }
}

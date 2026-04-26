import 'dart:io';

void main() {
  patchGradleDesugaring();
  patchAndroidManifestPermissions();
}

void patchGradleDesugaring() {
  final kotlinGradle = File('android/app/build.gradle.kts');
  final groovyGradle = File('android/app/build.gradle');

  if (kotlinGradle.existsSync()) {
    var text = kotlinGradle.readAsStringSync();

    if (!text.contains('isCoreLibraryDesugaringEnabled')) {
      if (text.contains('compileOptions {')) {
        text = text.replaceFirst(
          'compileOptions {',
          'compileOptions {\n        isCoreLibraryDesugaringEnabled = true',
        );
      } else {
        text = text.replaceFirst(
          'android {',
          'android {\n    compileOptions {\n        sourceCompatibility = JavaVersion.VERSION_17\n        targetCompatibility = JavaVersion.VERSION_17\n        isCoreLibraryDesugaringEnabled = true\n    }',
        );
      }
    }

    if (!text.contains('desugar_jdk_libs')) {
      const dependency = '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n';
      if (text.contains('dependencies {')) {
        text = text.replaceFirst('dependencies {', 'dependencies {\n$dependency');
      } else {
        text = '$text\n\ndependencies {\n$dependency}\n';
      }
    }

    kotlinGradle.writeAsStringSync(text);
    return;
  }

  if (groovyGradle.existsSync()) {
    var text = groovyGradle.readAsStringSync();

    if (!text.contains('coreLibraryDesugaringEnabled')) {
      if (text.contains('compileOptions {')) {
        text = text.replaceFirst(
          'compileOptions {',
          'compileOptions {\n        coreLibraryDesugaringEnabled true',
        );
      } else {
        text = text.replaceFirst(
          'android {',
          'android {\n    compileOptions {\n        sourceCompatibility JavaVersion.VERSION_17\n        targetCompatibility JavaVersion.VERSION_17\n        coreLibraryDesugaringEnabled true\n    }',
        );
      }
    }

    if (!text.contains('desugar_jdk_libs')) {
      const dependency = "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'\n";
      if (text.contains('dependencies {')) {
        text = text.replaceFirst('dependencies {', 'dependencies {\n$dependency');
      } else {
        text = '$text\n\ndependencies {\n$dependency}\n';
      }
    }

    groovyGradle.writeAsStringSync(text);
    return;
  }

  stderr.writeln('Nenhum arquivo Gradle Android encontrado em android/app.');
  exit(1);
}

void patchAndroidManifestPermissions() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stderr.writeln('AndroidManifest.xml não encontrado.');
    exit(1);
  }

  var text = manifest.readAsStringSync();
  final permissions = <String>[
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
    '<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />',
    '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />',
  ];

  final missingPermissions = permissions.where((permission) {
    final nameMatch = RegExp(r'android:name="([^"]+)"').firstMatch(permission);
    final name = nameMatch?.group(1);
    return name != null && !text.contains(name);
  }).toList();

  if (missingPermissions.isEmpty) return;

  final manifestTag = RegExp(r'<manifest[^>]*>').firstMatch(text);
  if (manifestTag == null) {
    stderr.writeln('Tag <manifest> não encontrada no AndroidManifest.xml.');
    exit(1);
  }

  final insertion = '\n    ${missingPermissions.join('\n    ')}';
  text = text.replaceRange(manifestTag.end, manifestTag.end, insertion);
  manifest.writeAsStringSync(text);
}

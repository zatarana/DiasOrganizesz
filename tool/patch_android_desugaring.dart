import 'dart:io';

void main() {
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

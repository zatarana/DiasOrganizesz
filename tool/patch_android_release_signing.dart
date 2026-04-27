import 'dart:io';

void main() {
  final kotlinGradle = File('android/app/build.gradle.kts');
  final groovyGradle = File('android/app/build.gradle');

  if (kotlinGradle.existsSync()) {
    _patchKotlinGradle(kotlinGradle);
    return;
  }

  if (groovyGradle.existsSync()) {
    _patchGroovyGradle(groovyGradle);
    return;
  }

  stderr.writeln('Nenhum arquivo Gradle Android encontrado em android/app.');
  exit(1);
}

void _patchKotlinGradle(File file) {
  var text = file.readAsStringSync();

  if (!text.contains('import java.util.Properties')) {
    text = 'import java.util.Properties\n\n$text';
  }

  if (!text.contains('val keystoreProperties = Properties()')) {
    final pluginsEnd = _findBlockEnd(text, text.indexOf('plugins {'));
    if (pluginsEnd == -1) {
      stderr.writeln('Bloco plugins não encontrado em build.gradle.kts.');
      exit(1);
    }
    const props = '''

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
''';
    text = text.replaceRange(pluginsEnd + 1, pluginsEnd + 1, props);
  }

  if (!text.contains('create("release")')) {
    final buildTypesIndex = text.indexOf('    buildTypes {');
    final androidIndex = text.indexOf('android {');
    if (androidIndex == -1) {
      stderr.writeln('Bloco android não encontrado em build.gradle.kts.');
      exit(1);
    }

    const signing = '''

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            storeType = (keystoreProperties["storeType"] as String?) ?: "pkcs12"
        }
    }
''';

    if (buildTypesIndex != -1) {
      text = text.replaceRange(buildTypesIndex, buildTypesIndex, signing);
    } else {
      final androidEnd = _findBlockEnd(text, androidIndex);
      if (androidEnd == -1) {
        stderr.writeln('Fim do bloco android não encontrado em build.gradle.kts.');
        exit(1);
      }
      text = text.replaceRange(androidEnd, androidEnd, '''$signing
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
''');
    }
  }

  text = text.replaceAll('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")');

  if (!text.contains('signingConfig = signingConfigs.getByName("release")')) {
    final releaseIndex = text.indexOf('        release {');
    if (releaseIndex != -1) {
      final insertionPoint = releaseIndex + '        release {'.length;
      text = text.replaceRange(insertionPoint, insertionPoint, '\n            signingConfig = signingConfigs.getByName("release")');
    }
  }

  file.writeAsStringSync(text);
}

void _patchGroovyGradle(File file) {
  var text = file.readAsStringSync();

  if (!text.contains('def keystoreProperties = new Properties()')) {
    const props = '''
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

''';
    text = '$props$text';
  }

  if (!text.contains('releaseSigning')) {
    final buildTypesIndex = text.indexOf('    buildTypes {');
    final androidIndex = text.indexOf('android {');
    if (androidIndex == -1) {
      stderr.writeln('Bloco android não encontrado em build.gradle.');
      exit(1);
    }

    const signing = '''

    signingConfigs {
        releaseSigning {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
            storeType keystoreProperties['storeType'] ?: 'pkcs12'
        }
    }
''';

    if (buildTypesIndex != -1) {
      text = text.replaceRange(buildTypesIndex, buildTypesIndex, signing);
    } else {
      final androidEnd = _findBlockEnd(text, androidIndex);
      if (androidEnd == -1) {
        stderr.writeln('Fim do bloco android não encontrado em build.gradle.');
        exit(1);
      }
      text = text.replaceRange(androidEnd, androidEnd, '''$signing
    buildTypes {
        release {
            signingConfig signingConfigs.releaseSigning
            minifyEnabled false
            shrinkResources false
        }
    }
''');
    }
  }

  text = text.replaceAll('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.releaseSigning');

  if (!text.contains('signingConfig signingConfigs.releaseSigning')) {
    final releaseIndex = text.indexOf('        release {');
    if (releaseIndex != -1) {
      final insertionPoint = releaseIndex + '        release {'.length;
      text = text.replaceRange(insertionPoint, insertionPoint, '\n            signingConfig signingConfigs.releaseSigning');
    }
  }

  file.writeAsStringSync(text);
}

int _findBlockEnd(String text, int blockStart) {
  if (blockStart < 0) return -1;
  final openIndex = text.indexOf('{', blockStart);
  if (openIndex == -1) return -1;

  var depth = 0;
  for (var i = openIndex; i < text.length; i++) {
    final char = text[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

#!/usr/bin/env bash
set -euo pipefail

# Flutter 3.38 generates registration entries for dev-only native plugins,
# while its release Gradle loader omits those plugins from the classpath.
python3 - <<'PY'
from pathlib import Path
import re

path = Path('android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java')
text = path.read_text()
for name in ('flutter_native_splash', 'patrol'):
    pattern = re.compile(
        r'    try \{\n'
        r'      flutterEngine\.getPlugins\(\)\.add\(new [^\n]+\);\n'
        r'    \} catch \(Exception e\) \{\n'
        r'      Log\.e\(TAG, "Error registering plugin ' + name + r', [^\n]+\n'
        r'    \}\n'
    )
    text, count = pattern.subn('', text)
    if count > 1:
        raise SystemExit(f'Expected at most one generated {name} registration, found {count}')
path.write_text(text)
PY

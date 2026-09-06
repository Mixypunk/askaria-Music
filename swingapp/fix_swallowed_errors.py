import os
import re

regex = re.compile(r'catch\s*\([^)]*\)\s*\{\s*\}')

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # If it doesn't have an empty catch, skip
    if not regex.search(content):
        return

    # Replace all matches
    filename = os.path.basename(filepath)
    new_content = regex.sub(f"catch (e, stack) {{ LoggerService.warning('Silent error caught in {filename}', e); }}", content)

    # Check if import is needed
    if 'logger_service.dart' not in new_content and filename != 'logger_service.dart':
        # find the last import and insert after it
        lines = new_content.split('\n')
        last_import = -1
        for i, line in enumerate(lines):
            if line.startswith('import '):
                last_import = i
        
        if last_import != -1:
            lines.insert(last_import + 1, "import 'package:askaria/services/logger_service.dart';")
        else:
            lines.insert(0, "import 'package:askaria/services/logger_service.dart';")
        
        new_content = '\n'.join(lines)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

print('Done fixing swallowed errors!')

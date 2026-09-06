import os
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    modified = False

    # 1. Fix unused stack trace: change "catch (e, stack) { LoggerService.warning(" to "catch (e) { LoggerService.warning("
    if 'catch (e, stack) { LoggerService.warning' in content:
        content = content.replace('catch (e, stack) { LoggerService.warning', 'catch (e) { LoggerService.warning')
        modified = True

    # 2. Check if it's a part file. If so, remove the import!
    if 'part of ' in content and "import 'package:askaria/services/logger_service.dart';" in content:
        content = content.replace("import 'package:askaria/services/logger_service.dart';\n", '')
        content = content.replace("import 'package:askaria/services/logger_service.dart';", '')
        modified = True

    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

print('Done fixing mistakes!')

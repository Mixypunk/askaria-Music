import os
import re

with open('lib/providers/player_provider.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

def find_method_line(name):
    for i, line in enumerate(lines):
        if re.search(r'^\s*(Future<.*>|void|bool|double) ' + name + r'\(', line):
            return i
    return -1

setCrossfade = find_method_line('setCrossfade')
initPlayer = find_method_line('_initPlayer')
playSong = find_method_line('playSong')
updateWidget = find_method_line('_updateWidget')
isFavourite = find_method_line('isFavourite')
restoreQueue = find_method_line('_restoreQueue')
dispose = find_method_line('dispose')

print(f"setCrossfade: {setCrossfade}")
print(f"initPlayer: {initPlayer}")
print(f"playSong: {playSong}")
print(f"updateWidget: {updateWidget}")
print(f"isFavourite: {isFavourite}")
print(f"restoreQueue: {restoreQueue}")
print(f"dispose: {dispose}")

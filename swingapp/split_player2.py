import os

with open('lib/providers/player_provider.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

os.makedirs('lib/providers/player', exist_ok=True)

# lines 0 to 104 -> main
# lines 105 to 162 -> part_crossfade
# lines 163 to 167 -> main
# lines 168 to 250 -> part_audio
# lines 251 to 478 -> part_queue
# lines 479 to 569 -> part_metadata
# lines 570 to 738 -> part_storage
# lines 739 to end -> main

def write_ext(name, start, end, out):
    with open(f'lib/providers/player/{out}.dart', 'w', encoding='utf-8') as f:
        f.write(f"part of '../player_provider.dart';\n\n")
        f.write(f"extension {name} on PlayerProvider {{\n")
        for line in lines[start:end]:
            f.write(line)
        f.write("}\n")

write_ext('PlayerCrossfade', 105, 163, 'player_crossfade')
write_ext('PlayerAudio', 168, 251, 'player_audio')
write_ext('PlayerQueueExt', 251, 479, 'player_queue')
write_ext('PlayerMetadata', 479, 570, 'player_metadata')
write_ext('PlayerStorage', 570, 739, 'player_storage')

with open('lib/providers/player_provider.dart', 'w', encoding='utf-8') as f:
    # imports (find last import)
    last_import = 0
    for i, line in enumerate(lines[:105]):
        if line.startswith('import '):
            last_import = i
    
    for i in range(last_import + 1):
        f.write(lines[i])
    
    f.write("\n")
    f.write("part 'player/player_crossfade.dart';\n")
    f.write("part 'player/player_audio.dart';\n")
    f.write("part 'player/player_queue.dart';\n")
    f.write("part 'player/player_metadata.dart';\n")
    f.write("part 'player/player_storage.dart';\n")
    f.write("\n")

    for i in range(last_import + 1, 105):
        f.write(lines[i])
    
    for i in range(163, 168):
        f.write(lines[i])
        
    for i in range(739, len(lines)):
        f.write(lines[i])

print('Done player_provider!')

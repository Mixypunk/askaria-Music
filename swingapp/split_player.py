import os
import re

with open('lib/providers/player_provider.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

def find_method_line(name):
    for i, line in enumerate(lines):
        if re.search(r'^\s*(Future<.*>|void|bool|double|AudioSource) ' + name + r'\(', line):
            return i
    return -1

methods = {
    'setCrossfade': find_method_line('setCrossfade'),
    '_initPlayer': find_method_line('_initPlayer'),
    '_buildSource': find_method_line('_buildSource'),
    '_rebuildPlaylist': find_method_line('_rebuildPlaylist'),
    'playSong': find_method_line('playSong'),
    'playPause': find_method_line('playPause'),
    'next': find_method_line('next'),
    'previous': find_method_line('previous'),
    'seek': find_method_line('seek'),
    'setVolume': find_method_line('setVolume'),
    'toggleRepeat': find_method_line('toggleRepeat'),
    'toggleShuffle': find_method_line('toggleShuffle'),
    'addToQueue': find_method_line('addToQueue'),
    'addNextInQueue': find_method_line('addNextInQueue'),
    'removeFromQueue': find_method_line('removeFromQueue'),
    'reorderQueue': find_method_line('reorderQueue'),
    '_updateWidget': find_method_line('_updateWidget'),
    '_fetchColors': find_method_line('_fetchColors'),
    '_fetchLyrics': find_method_line('_fetchLyrics'),
    'isFavourite': find_method_line('isFavourite'),
    'toggleFavourite': find_method_line('toggleFavourite'),
    '_loadFavourites': find_method_line('_loadFavourites'),
    'getCachedPlaylists': find_method_line('getCachedPlaylists'),
    'invalidatePlaylistsCache': find_method_line('invalidatePlaylistsCache'),
    'setSleepTimer': find_method_line('setSleepTimer'),
    'cancelSleepTimer': find_method_line('cancelSleepTimer'),
    '_addToHistory': find_method_line('_addToHistory'),
    '_restoreQueue': find_method_line('_restoreQueue'),
    '_persistQueue': find_method_line('_persistQueue'),
    'dispose': find_method_line('dispose'),
}

sorted_methods = sorted(methods.items(), key=lambda x: x[1])
for m in sorted_methods:
    print(f"{m[1]}: {m[0]}")

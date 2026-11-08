import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../services/api_service.dart';
import '../services/server_status.dart';
import '../providers/player_provider.dart';
import '../providers/downloads_provider.dart';
import '../widgets/artwork_widget.dart';
import '../widgets/avatar_image.dart';
import '../widgets/offline/offline_components.dart';
import 'settings_screen.dart';
import 'artist_screen.dart';
import 'playlists_screen.dart';
import 'downloads_screen.dart';


part 'home/home_main.dart';
part 'home/home_components.dart';
part 'home/all_songs_screen.dart';
part 'home/offline_home.dart';

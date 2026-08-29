import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../widgets/artwork_widget.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../models/album.dart';
import 'artist_screen.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/downloads_provider.dart';
import '../providers/connect_controller_provider.dart';


part 'player/player_main.dart';
part 'player/player_page.dart';
part 'player/player_lyrics.dart';
part 'player/player_queue.dart';
part 'player/components.dart';

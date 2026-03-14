class Song {
  final String hash;       // trackhash
  final String title;
  final String artist;
  final String album;
  final String albumHash;
  final String artistHash;
  final int duration;
  final int trackNumber;
  final String? filepath;  // chemin du fichier sur le serveur
  final String? image;     // hash de l'image (track.image dans l'app officielle)

  const Song({
    required this.hash,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumHash,
    required this.artistHash,
    required this.duration,
    this.trackNumber = 0,
    this.filepath,
    this.image,
  });

  factory Song.fromJson(Map<String, dynamic> j) => Song(
    hash: j['trackhash'] ?? j['hash'] ?? '',
    title: j['title'] ?? 'Unknown',
    artist: _extractArtist(j),
    album: j['album'] ?? 'Unknown Album',
    albumHash: j['albumhash'] ?? j['album_hash'] ?? '',
    artistHash: _extractArtistHash(j),
    duration: (j['duration'] ?? 0).toInt(),
    trackNumber: j['track'] ?? j['trackno'] ?? 0,
    filepath: j['filepath'] ?? j['path'] ?? j['file_path'],
    image: j['image'] ?? '',  // = '{albumhash}.webp?pathhash={pathhash}'
  );

  static String _extractArtist(Map<String, dynamic> j) {
    if (j['artists'] is List && (j['artists'] as List).isNotEmpty) {
      return (j['artists'] as List).map((a) => a['name'] ?? '').join(', ');
    }
    if (j['albumartists'] is List && (j['albumartists'] as List).isNotEmpty) {
      return (j['albumartists'] as List).map((a) => a['name'] ?? '').join(', ');
    }
    return j['artist'] ?? j['albumartist'] ?? 'Unknown Artist';
  }

  static String _extractArtistHash(Map<String, dynamic> j) {
    if (j['artists'] is List && (j['artists'] as List).isNotEmpty) {
      return (j['artists'] as List).first['artisthash'] ?? '';
    }
    if (j['albumartists'] is List && (j['albumartists'] as List).isNotEmpty) {
      return (j['albumartists'] as List).first['artisthash'] ?? '';
    }
    return j['artisthash'] ?? '';
  }

  String get formattedDuration {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) => other is Song && other.hash == hash;

  @override
  int get hashCode => hash.hashCode;
}

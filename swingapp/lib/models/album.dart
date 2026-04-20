class Album {
  final String hash;
  final String title;
  final String artist;
  final String artistHash;
  final int? year;
  final int trackCount;
  final String image; // "{albumhash}.webp?pathhash={pathhash}"

  const Album({
    required this.hash,
    required this.title,
    required this.artist,
    required this.artistHash,
    this.year,
    this.trackCount = 0,
    this.image = '',
  });

  factory Album.fromJson(Map<String, dynamic> j) => Album(
    hash: j['albumhash'] ?? j['hash'] ?? '',
    title: j['title'] ?? 'Unknown Album',
    artist: _extractArtist(j),
    artistHash: _extractArtistHash(j),
    year: j['date'] != null ? int.tryParse(j['date'].toString().substring(0, 4)) : null,
    trackCount: j['count'] ?? j['trackcount'] ?? 0,
    image: j['image'] ?? '',
  );

  static String _extractArtist(Map<String, dynamic> j) {
    if (j['albumartists'] is List && (j['albumartists'] as List).isNotEmpty) {
      return (j['albumartists'] as List).map((a) => a['name'] ?? '').join(', ');
    }
    return j['artist'] ?? 'Unknown Artist';
  }

  static String _extractArtistHash(Map<String, dynamic> j) {
    if (j['albumartists'] is List && (j['albumartists'] as List).isNotEmpty) {
      return (j['albumartists'] as List).first['artisthash'] ?? '';
    }
    return j['artisthash'] ?? '';
  }
}

class Artist {
  final String hash;
  final String name;
  final int albumCount;
  final int trackCount;
  final String image; // "{artisthash}.webp" → /img/artist/small/{artisthash}.webp

  const Artist({
    required this.hash,
    required this.name,
    this.albumCount = 0,
    this.trackCount = 0,
    this.image = '',
    this.helpText = '',
  });

  final String helpText; // extra info from server (e.g. "5 tracks")

  factory Artist.fromJson(Map<String, dynamic> j) {
    final hash = j['artisthash'] ?? j['hash'] ?? '';
    return Artist(
      hash: hash,
      name: j['name'] ?? 'Unknown Artist',
      albumCount: j['albumcount'] ?? 0,
      trackCount: j['trackcount'] ?? 0,
      image: j['image'] ?? '$hash.webp',
      helpText: j['help_text']?.toString() ?? '',
    );
  }
}

class Playlist {
  final String id;
  final String name;
  final String? description;
  final int trackCount;
  final String? imageHash;
  final bool isPublic;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.trackCount = 0,
    this.imageHash,
    this.isPublic = false,
  });

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
    id: j['id']?.toString() ?? '',
    name: j['name'] ?? 'Unnamed Playlist',
    description: j['extra']?['description'] ?? j['description'],
    trackCount: j['count'] ?? j['trackcount'] ?? 0,
    // playlist image served at /img/playlist/{id}.webp
    imageHash: j['id']?.toString(),
    isPublic: j['is_public'] == true || j['is_public'] == 1,
  );
}

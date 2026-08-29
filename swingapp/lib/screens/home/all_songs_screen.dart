part of '../home_tab.dart';

class _AllSongsScreen extends StatelessWidget {
  final List<Song> songs;
  const _AllSongsScreen({required this.songs});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: Text('${songs.length} titres',
          style: const TextStyle(color: Sp.white,
              fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 30, color: Sp.white),
          onPressed: () => Navigator.pop(context)),
      ),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (ctx, i) =>
            _SongRow(song: songs[i], all: songs, idx: i, index: i),
      ),
    );
  }
}

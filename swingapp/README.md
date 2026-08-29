# 🎵 SwingApp — Ton client Android pour Swing Music

Application Flutter personnalisée pour streamer ta musique depuis ton serveur Swing Music.

---

## ✅ Fonctionnalités

- 🎵 Lecture / Pause / Skip
- 📋 File d'attente (queue) réordonnée drag & drop
- 💿 Albums avec pochettes
- 🎤 Artistes
- 📂 Playlists
- 🔍 Recherche en temps réel
- 📝 Paroles (lyrics)
- 🔁 Répétition (off / all / one)
- 🔀 Shuffle
- 🌙 Thème sombre automatique (suit le système)

---

## 🚀 Installation

### 1. Prérequis
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.0+)
- Android Studio ou VS Code avec le plugin Flutter
- Un téléphone Android ou émulateur

### 2. Build l'APK

```bash
# Dans le dossier swingapp/
flutter pub get
flutter build apk --release
```

L'APK sera dans : `build/outputs/flutter-apk/app-release.apk`

### 3. Installer sur ton téléphone
```bash
flutter install
# ou transfère l'APK et installe manuellement
```

---

## 🌐 Exposer Swing Music sur Internet

Pour accéder à ta musique hors de chez toi (depuis ton NAS/Raspberry Pi) :

### Option A — Tailscale (plus simple, recommandée ✅)
1. Installe [Tailscale](https://tailscale.com) sur ton NAS/Pi et ton téléphone
2. Aucune configuration routeur nécessaire
3. Utilise l'IP Tailscale dans l'app : `http://100.x.x.x:1970`

### Option B — Port forwarding
1. Dans ton routeur, redirige le **port 1970** vers l'IP locale de ton NAS/Pi
2. Trouve ton IP publique sur [whatismyip.com](https://whatismyip.com)
3. Utilise un **DDNS** gratuit (ex: [DuckDNS](https://duckdns.org)) pour avoir un nom de domaine fixe
4. Utilise dans l'app : `http://ton-domaine.duckdns.org:1970`

### Option C — Reverse proxy avec HTTPS (avancé)
1. Installe Nginx ou Caddy sur ton Pi
2. Configure un proxy vers `localhost:1970`
3. Utilise Let's Encrypt pour le certificat SSL

---

## ⚙️ Configuration dans l'app

Au premier lancement, l'app te demande l'URL de ton serveur :

- **Local (Wi-Fi)** : `http://192.168.1.100:1970`
- **Via Tailscale** : `http://100.x.x.x:1970`
- **Via DDNS** : `http://ton-domaine.duckdns.org:1970`
- **Avec HTTPS** : `https://musique.ton-domaine.com`

---

## 📦 Dépendances principales

| Package | Rôle |
|---|---|
| `just_audio` | Lecteur audio |
| `provider` | State management |
| `cached_network_image` | Cache des pochettes |
| `shared_preferences` | Sauvegarde des paramètres |
| `http` | Appels à l'API Swing Music |

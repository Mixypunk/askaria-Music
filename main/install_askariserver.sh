#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  AskariServer — Script d'installation automatique TrueNAS SCALE
#  Pool Apps    : /mnt/Apps
#  Pool Musique : /mnt/NAS/Media/Music
# ═══════════════════════════════════════════════════════════════════

set -e
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       🎵 AskariServer Installer       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""

# ── Chemins ────────────────────────────────────────────────────────
APPS_DIR="/mnt/Apps/askariserver"
MUSIC_DIR="/mnt/NAS/Media/Music"
DATA_DIR="$APPS_DIR/data"
CACHE_DIR="$DATA_DIR/cache"

# ── Vérifications préliminaires ────────────────────────────────────
info "Vérification de l'environnement..."

[ -d "/mnt/Apps" ]        || error "Pool Apps introuvable : /mnt/Apps"
[ -d "$MUSIC_DIR" ]       || error "Musique introuvable : $MUSIC_DIR"
command -v docker &>/dev/null || error "Docker non disponible"
ok "Environnement OK"

# ── Création des dossiers ──────────────────────────────────────────
info "Création des dossiers..."
mkdir -p "$APPS_DIR/app/routers"
mkdir -p "$APPS_DIR/app/compat"
mkdir -p "$APPS_DIR/chart/templates"
mkdir -p "$DATA_DIR/cache"
ok "Dossiers créés dans $APPS_DIR"

# ── Génération de la clé secrète ───────────────────────────────────
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(48))")
ok "Clé secrète générée"

# ════════════════════════════════════════════════════════════════════
#  FICHIERS DU PROJET
# ════════════════════════════════════════════════════════════════════

info "Création des fichiers du projet..."

# ── requirements.txt ──────────────────────────────────────────────
cat > "$APPS_DIR/requirements.txt" << 'EOF'
fastapi==0.111.0
uvicorn[standard]==0.29.0
python-multipart==0.0.9
pydantic==2.7.1
pydantic-settings==2.2.1
sqlalchemy[asyncio]==2.0.30
aiosqlite==0.20.0
pyjwt==2.8.0
bcrypt==4.1.3
mutagen==1.47.0
Pillow==10.3.0
httpx==0.27.0
python-dotenv==1.0.1
aiofiles==23.2.1
EOF
ok "requirements.txt"

# ── Dockerfile ────────────────────────────────────────────────────
cat > "$APPS_DIR/Dockerfile" << 'EOF'
FROM python:3.11-slim
LABEL description="AskariServer - Streaming musical maison"
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg libmagic1 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /askariserver
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
VOLUME ["/music", "/data"]
EXPOSE 7777
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:7777/health')"
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7777", \
     "--workers", "2", "--proxy-headers", "--forwarded-allow-ips", "*"]
EOF
ok "Dockerfile"

# ── docker-compose.yml ────────────────────────────────────────────
cat > "$APPS_DIR/docker-compose.yml" << EOF
services:
  askariserver:
    image: askariserver:latest
    container_name: askariserver
    restart: unless-stopped
    ports:
      - "7777:7777"
    volumes:
      - $MUSIC_DIR:/music:ro
      - $DATA_DIR:/data
    environment:
      SECRET_KEY: "$SECRET_KEY"
      MUSIC_DIRS: "/music"
      AUTO_SCAN_ON_START: "true"
      DATABASE_URL: "sqlite+aiosqlite:////data/askari.db"
      CACHE_DIR: "/data/cache"
      TRANSCODING_ENABLED: "true"
      FFMPEG_PATH: "ffmpeg"
      TRUST_PROXY_HEADERS: "true"
      ALLOW_REGISTRATION: "false"
    healthcheck:
      test: ["CMD", "python3", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:7777/health')"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
EOF
ok "docker-compose.yml"

# ── app/__init__.py ───────────────────────────────────────────────
cat > "$APPS_DIR/app/__init__.py" << 'EOF'
# AskariServer
EOF

# ── app/config.py ─────────────────────────────────────────────────
cat > "$APPS_DIR/app/config.py" << 'EOF'
from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    HOST: str = "0.0.0.0"
    PORT: int = 7777
    SECRET_KEY: str = "change-me"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    MUSIC_DIRS: str = "/music"
    AUTO_SCAN_ON_START: bool = True
    SCAN_INTERVAL_HOURS: int = 24
    DATABASE_URL: str = "sqlite+aiosqlite:////data/askari.db"
    CACHE_DIR: str = "/data/cache"
    THUMB_SIZE: int = 300
    FFMPEG_PATH: str = "ffmpeg"
    TRANSCODING_ENABLED: bool = True
    DEFAULT_QUALITY: str = "high"
    LRCLIB_BASE: str = "https://lrclib.net/api"
    LYRICS_CACHE_DAYS: int = 30
    ALLOW_REGISTRATION: bool = False
    MAX_USERS: int = 10
    TRUST_PROXY_HEADERS: bool = True

    @property
    def music_dirs_list(self) -> List[str]:
        return [d.strip() for d in self.MUSIC_DIRS.split(":") if d.strip()]

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
EOF
ok "app/config.py"

# ── app/database.py ───────────────────────────────────────────────
cat > "$APPS_DIR/app/database.py" << 'EOF'
from sqlalchemy import (Column, String, Integer, Float, Boolean, DateTime,
    ForeignKey, Text, BigInteger, Index)
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase, relationship
from datetime import datetime
from .config import settings
import os

os.makedirs("/data", exist_ok=True)
engine = create_async_engine(settings.DATABASE_URL, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = "users"
    id         = Column(Integer, primary_key=True, index=True)
    username   = Column(String(50), unique=True, nullable=False, index=True)
    password   = Column(String(200), nullable=False)
    role       = Column(String(20), default="user")
    created_at = Column(DateTime, default=datetime.utcnow)
    last_seen  = Column(DateTime, nullable=True)
    is_active  = Column(Boolean, default=True)
    playlists  = relationship("Playlist", back_populates="owner", cascade="all, delete-orphan")
    favourites = relationship("Favourite", back_populates="user", cascade="all, delete-orphan")
    history    = relationship("PlayHistory", back_populates="user", cascade="all, delete-orphan")

class Artist(Base):
    __tablename__ = "artists"
    id         = Column(Integer, primary_key=True, index=True)
    name       = Column(String(300), nullable=False, index=True)
    name_sort  = Column(String(300), nullable=True)
    image      = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    albums     = relationship("Album", back_populates="artist")
    songs      = relationship("Song", back_populates="artist")

class Album(Base):
    __tablename__ = "albums"
    id          = Column(Integer, primary_key=True, index=True)
    title       = Column(String(300), nullable=False, index=True)
    artist_id   = Column(Integer, ForeignKey("artists.id"), nullable=True)
    year        = Column(Integer, nullable=True)
    genre       = Column(String(100), nullable=True)
    image       = Column(String(500), nullable=True)
    track_count = Column(Integer, default=0)
    duration    = Column(Integer, default=0)
    hash        = Column(String(32), unique=True, nullable=False, index=True)
    created_at  = Column(DateTime, default=datetime.utcnow)
    artist      = relationship("Artist", back_populates="albums")
    songs       = relationship("Song", back_populates="album", order_by="Song.track_number")

class Song(Base):
    __tablename__ = "songs"
    id            = Column(Integer, primary_key=True, index=True)
    title         = Column(String(300), nullable=False, index=True)
    artist_id     = Column(Integer, ForeignKey("artists.id"), nullable=True)
    album_id      = Column(Integer, ForeignKey("albums.id"), nullable=True)
    filepath      = Column(String(1000), unique=True, nullable=False)
    filename      = Column(String(300), nullable=False)
    duration      = Column(Integer, default=0)
    track_number  = Column(Integer, nullable=True)
    disc_number   = Column(Integer, nullable=True)
    year          = Column(Integer, nullable=True)
    genre         = Column(String(100), nullable=True)
    bitrate       = Column(Integer, nullable=True)
    sample_rate   = Column(Integer, nullable=True)
    format        = Column(String(10), nullable=True)
    file_size     = Column(BigInteger, nullable=True)
    image         = Column(String(500), nullable=True)
    image_hash    = Column(String(32), nullable=True)
    hash          = Column(String(32), unique=True, nullable=False, index=True)
    play_count    = Column(Integer, default=0)
    last_played   = Column(DateTime, nullable=True)
    date_added    = Column(DateTime, default=datetime.utcnow)
    date_modified = Column(DateTime, nullable=True)
    artist        = relationship("Artist", back_populates="songs")
    album         = relationship("Album", back_populates="songs")
    playlist_entries = relationship("PlaylistEntry", back_populates="song")
    history       = relationship("PlayHistory", back_populates="song")

class Playlist(Base):
    __tablename__ = "playlists"
    id          = Column(Integer, primary_key=True, index=True)
    name        = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    owner_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    is_public   = Column(Boolean, default=False)
    created_at  = Column(DateTime, default=datetime.utcnow)
    updated_at  = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    owner       = relationship("User", back_populates="playlists")
    entries     = relationship("PlaylistEntry", back_populates="playlist",
                               order_by="PlaylistEntry.position", cascade="all, delete-orphan")

class PlaylistEntry(Base):
    __tablename__ = "playlist_entries"
    id          = Column(Integer, primary_key=True, index=True)
    playlist_id = Column(Integer, ForeignKey("playlists.id"), nullable=False)
    song_id     = Column(Integer, ForeignKey("songs.id"), nullable=False)
    position    = Column(Integer, nullable=False)
    added_at    = Column(DateTime, default=datetime.utcnow)
    playlist    = relationship("Playlist", back_populates="entries")
    song        = relationship("Song", back_populates="playlist_entries")

class Favourite(Base):
    __tablename__ = "favourites"
    id       = Column(Integer, primary_key=True, index=True)
    user_id  = Column(Integer, ForeignKey("users.id"), nullable=False)
    song_id  = Column(Integer, ForeignKey("songs.id"), nullable=False)
    added_at = Column(DateTime, default=datetime.utcnow)
    user     = relationship("User", back_populates="favourites")
    song     = relationship("Song")

class PlayHistory(Base):
    __tablename__ = "play_history"
    id              = Column(Integer, primary_key=True, index=True)
    user_id         = Column(Integer, ForeignKey("users.id"), nullable=False)
    song_id         = Column(Integer, ForeignKey("songs.id"), nullable=False)
    played_at       = Column(DateTime, default=datetime.utcnow, index=True)
    duration_played = Column(Integer, default=0)
    completed       = Column(Boolean, default=False)
    user            = relationship("User", back_populates="history")
    song            = relationship("Song", back_populates="history")

class LyricsCache(Base):
    __tablename__ = "lyrics_cache"
    id        = Column(Integer, primary_key=True, index=True)
    song_id   = Column(Integer, ForeignKey("songs.id"), unique=True)
    synced    = Column(Boolean, default=False)
    content   = Column(Text, nullable=True)
    source    = Column(String(50), nullable=True)
    cached_at = Column(DateTime, default=datetime.utcnow)

async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
EOF
ok "app/database.py"

# ── app/scanner.py ────────────────────────────────────────────────
cat > "$APPS_DIR/app/scanner.py" << 'EOF'
import asyncio, hashlib, os, logging
from pathlib import Path
from typing import Optional
from datetime import datetime
import mutagen
from mutagen.id3 import ID3
from mutagen.flac import FLAC
from mutagen.mp4 import MP4
from PIL import Image
import io
from .database import AsyncSessionLocal, Song, Artist, Album
from .config import settings
from sqlalchemy import select

logger = logging.getLogger(__name__)
SUPPORTED_FORMATS = {".mp3",".flac",".wav",".aiff",".aif",".m4a",".aac",".ogg",".opus",".wv",".ape"}

def make_hash(text: str) -> str:
    return hashlib.md5(text.encode()).hexdigest()[:16]

class LibraryScanner:
    def __init__(self):
        self._scanning = False
        self._progress = {"total": 0, "done": 0, "current": ""}

    @property
    def progress(self): return self._progress
    @property
    def is_scanning(self): return self._scanning

    async def scan_all(self):
        if self._scanning:
            return
        self._scanning = True
        logger.info("🔍 Scan de bibliothèque démarré...")
        try:
            all_files = []
            for music_dir in settings.music_dirs_list:
                if os.path.exists(music_dir):
                    for root, _, files in os.walk(music_dir):
                        for f in files:
                            if Path(f).suffix.lower() in SUPPORTED_FORMATS:
                                all_files.append(os.path.join(root, f))
            self._progress["total"] = len(all_files)
            logger.info(f"📁 {len(all_files)} fichiers trouvés")
            for i, filepath in enumerate(all_files):
                self._progress["done"] = i
                self._progress["current"] = os.path.basename(filepath)
                await self._process_file(filepath)
                if i % 50 == 0:
                    await asyncio.sleep(0)
            logger.info(f"✅ Scan terminé : {len(all_files)} fichiers")
        except Exception as e:
            logger.error(f"Erreur scan: {e}")
        finally:
            self._scanning = False
            self._progress = {"total": 0, "done": 0, "current": ""}

    async def _process_file(self, filepath: str):
        try:
            async with AsyncSessionLocal() as db:
                result = await db.execute(select(Song).where(Song.filepath == filepath))
                existing = result.scalar_one_or_none()
                mtime = datetime.fromtimestamp(os.path.getmtime(filepath))
                if existing and existing.date_modified == mtime:
                    return
                meta = self._extract_metadata(filepath)
                if not meta:
                    return
                artist = await self._get_or_create_artist(db, meta["artist"])
                album  = await self._get_or_create_album(db, meta, artist)
                thumb  = await self._extract_thumbnail(filepath, meta)
                if existing:
                    existing.title = meta["title"]
                    existing.duration = meta["duration"]
                    existing.track_number = meta["track_number"]
                    existing.image = thumb
                    existing.artist_id = artist.id if artist else None
                    existing.album_id  = album.id if album else None
                    existing.date_modified = mtime
                else:
                    song = Song(
                        filepath=filepath, filename=os.path.basename(filepath),
                        title=meta["title"], duration=meta["duration"],
                        track_number=meta["track_number"], disc_number=meta["disc_number"],
                        year=meta["year"], genre=meta["genre"],
                        bitrate=meta["bitrate"], sample_rate=meta["sample_rate"],
                        format=meta["format"], file_size=os.path.getsize(filepath),
                        image=thumb, image_hash=make_hash(thumb or filepath),
                        hash=make_hash(filepath),
                        artist_id=artist.id if artist else None,
                        album_id=album.id if album else None,
                        date_modified=mtime,
                    )
                    db.add(song)
                await db.commit()
        except Exception as e:
            logger.debug(f"Erreur {filepath}: {e}")

    def _extract_metadata(self, filepath: str) -> Optional[dict]:
        try:
            audio = mutagen.File(filepath, easy=True)
            if audio is None: return None
            def tag(k, d=""): v = audio.get(k, [d]); return str(v[0]) if v else d
            def tag_int(k):
                try: v = tag(k, "0"); return int(v.split("/")[0]) if v else None
                except: return None
            return {
                "title": tag("title") or os.path.splitext(os.path.basename(filepath))[0],
                "artist": tag("artist") or tag("albumartist") or "Artiste inconnu",
                "album": tag("album") or "Album inconnu",
                "year": tag_int("date") or tag_int("year"),
                "genre": tag("genre"), "track_number": tag_int("tracknumber"),
                "disc_number": tag_int("discnumber"),
                "duration": int(audio.info.length) if audio.info else 0,
                "bitrate": getattr(audio.info, "bitrate", None),
                "sample_rate": getattr(audio.info, "sample_rate", None),
                "format": Path(filepath).suffix.lower().lstrip("."),
            }
        except: return None

    async def _get_or_create_artist(self, db, name: str):
        if not name: return None
        r = await db.execute(select(Artist).where(Artist.name == name))
        a = r.scalar_one_or_none()
        if not a:
            a = Artist(name=name, name_sort=name.lower())
            db.add(a); await db.flush()
        return a

    async def _get_or_create_album(self, db, meta, artist):
        title = meta.get("album", "")
        if not title: return None
        h = make_hash(f"{meta['artist']}_{title}")
        r = await db.execute(select(Album).where(Album.hash == h))
        a = r.scalar_one_or_none()
        if not a:
            a = Album(title=title, artist_id=artist.id if artist else None,
                      year=meta.get("year"), genre=meta.get("genre"), hash=h)
            db.add(a); await db.flush()
        return a

    async def _extract_thumbnail(self, filepath, meta) -> Optional[str]:
        try:
            os.makedirs(settings.CACHE_DIR, exist_ok=True)
            h = make_hash(f"{meta['artist']}_{meta['album']}")
            path = os.path.join(settings.CACHE_DIR, f"{h}.webp")
            if os.path.exists(path): return path
            img_data = None
            ext = Path(filepath).suffix.lower()
            if ext == ".mp3":
                tags = ID3(filepath)
                for t in tags.values():
                    if t.FrameID == "APIC": img_data = t.data; break
            elif ext == ".flac":
                a = FLAC(filepath)
                if a.pictures: img_data = a.pictures[0].data
            elif ext in (".m4a", ".aac"):
                a = MP4(filepath)
                if "covr" in a.tags: img_data = bytes(a.tags["covr"][0])
            if img_data:
                img = Image.open(io.BytesIO(img_data)).convert("RGB")
                img.thumbnail((settings.THUMB_SIZE, settings.THUMB_SIZE))
                img.save(path, "WEBP", quality=85)
                return path
        except: pass
        return None

scanner = LibraryScanner()
EOF
ok "app/scanner.py"

# ── app/routers/__init__.py ───────────────────────────────────────
touch "$APPS_DIR/app/routers/__init__.py"
touch "$APPS_DIR/app/compat/__init__.py"

# ── app/routers/auth.py ───────────────────────────────────────────
cat > "$APPS_DIR/app/routers/auth.py" << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from datetime import datetime, timedelta
from typing import Optional
import bcrypt, jwt
from ..database import get_db, User
from ..config import settings

router = APIRouter()
security = HTTPBearer(auto_error=False)

def create_token(user_id: int, token_type: str = "access") -> str:
    expire = datetime.utcnow() + (
        timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        if token_type == "access" else timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS))
    return jwt.encode({"sub": str(user_id), "type": token_type, "exp": expire},
                      settings.SECRET_KEY, algorithm="HS256")

def decode_token(token: str):
    try: return jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    except jwt.ExpiredSignatureError: raise HTTPException(401, "Token expiré")
    except: raise HTTPException(401, "Token invalide")

async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    if not credentials: raise HTTPException(401, "Non authentifié")
    payload = decode_token(credentials.credentials)
    if payload.get("type") != "access": raise HTTPException(401, "Token invalide")
    user = await db.get(User, int(payload["sub"]))
    if not user or not user.is_active: raise HTTPException(401, "Utilisateur introuvable")
    user.last_seen = datetime.utcnow()
    await db.commit()
    return user

async def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != "admin": raise HTTPException(403, "Accès admin requis")
    return user

class LoginRequest(BaseModel):
    username: str
    password: str

class RefreshRequest(BaseModel):
    token: str

class SetupRequest(BaseModel):
    username: str
    password: str

@router.post("/login")
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(User).where(User.username == req.username))
    user = r.scalar_one_or_none()
    if not user or not bcrypt.checkpw(req.password.encode(), user.password.encode()):
        raise HTTPException(401, "Identifiants incorrects")
    return {"accesstoken": create_token(user.id), "refreshtoken": create_token(user.id, "refresh"),
            "user": {"id": user.id, "username": user.username, "role": user.role}}

@router.post("/refresh")
async def refresh_token(req: RefreshRequest, db: AsyncSession = Depends(get_db)):
    payload = decode_token(req.token)
    if payload.get("type") != "refresh": raise HTTPException(401, "Token invalide")
    user = await db.get(User, int(payload["sub"]))
    if not user: raise HTTPException(401, "Introuvable")
    return {"accesstoken": create_token(user.id), "refreshtoken": create_token(user.id, "refresh")}

@router.get("/user")
async def get_user_info(user: User = Depends(get_current_user)):
    return {"id": user.id, "username": user.username, "role": user.role}

@router.get("/users")
async def list_users(db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(User).where(User.is_active == True))
    return {"users": [{"username": u.username} for u in r.scalars().all()]}

@router.post("/setup")
async def setup(req: SetupRequest, db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(User))
    if r.scalars().first(): raise HTTPException(400, "Setup déjà effectué")
    hashed = bcrypt.hashpw(req.password.encode(), bcrypt.gensalt()).decode()
    user = User(username=req.username, password=hashed, role="admin")
    db.add(user); await db.commit(); await db.refresh(user)
    return {"message": f"Admin '{req.username}' créé",
            "accesstoken": create_token(user.id),
            "refreshtoken": create_token(user.id, "refresh")}
EOF
ok "app/routers/auth.py"

# ── app/routers/stream.py ─────────────────────────────────────────
cat > "$APPS_DIR/app/routers/stream.py" << 'EOF'
import asyncio, os, logging
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ..database import get_db, Song, PlayHistory, User
from ..routers.auth import get_current_user
from ..config import settings

router = APIRouter()
logger = logging.getLogger(__name__)

QUALITY_PRESETS = {
    "low":      {"codec": "libmp3lame", "bitrate": "128k", "ext": "mp3"},
    "medium":   {"codec": "libmp3lame", "bitrate": "192k", "ext": "mp3"},
    "high":     {"codec": "libmp3lame", "bitrate": "320k", "ext": "mp3"},
    "lossless": None,
}

def _mime(filepath):
    return {".mp3":"audio/mpeg",".flac":"audio/flac",".wav":"audio/wav",
            ".m4a":"audio/mp4",".aac":"audio/aac",".ogg":"audio/ogg",
            ".opus":"audio/opus",".aiff":"audio/aiff"}.get(
                os.path.splitext(filepath)[1].lower(), "audio/mpeg")

async def _stream_file(request: Request, filepath: str):
    file_size = os.path.getsize(filepath)
    rh = request.headers.get("range")
    if rh:
        parts = rh.replace("bytes=", "").split("-")
        start = int(parts[0]) if parts[0] else 0
        end = int(parts[1]) if len(parts) > 1 and parts[1] else file_size - 1
        end = min(end, file_size - 1)
        length = end - start + 1
        def gen():
            with open(filepath, "rb") as f:
                f.seek(start); rem = length
                while rem > 0:
                    d = f.read(min(65536, rem))
                    if not d: break
                    rem -= len(d); yield d
        return StreamingResponse(gen(), status_code=206, media_type=_mime(filepath),
            headers={"Content-Range": f"bytes {start}-{end}/{file_size}",
                     "Accept-Ranges": "bytes", "Content-Length": str(length)})
    def gen():
        with open(filepath, "rb") as f:
            while chunk := f.read(65536): yield chunk
    return StreamingResponse(gen(), media_type=_mime(filepath),
        headers={"Accept-Ranges": "bytes", "Content-Length": str(file_size)})

@router.get("/stream/{song_id}")
async def stream_song(song_id: int, request: Request, quality: str = "lossless",
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    song = await db.get(Song, song_id)
    if not song or not os.path.exists(song.filepath):
        raise HTTPException(404, "Fichier introuvable")
    asyncio.create_task(_record_play(song.id, user.id))
    return await _stream_file(request, song.filepath)

@router.get("/file/{song_hash}/legacy")
async def stream_by_hash(song_hash: str, request: Request, bitrate: str = "0",
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    r = await db.execute(select(Song).where(Song.hash == song_hash))
    song = r.scalar_one_or_none()
    if not song or not os.path.exists(song.filepath):
        raise HTTPException(404, "Fichier introuvable")
    asyncio.create_task(_record_play(song.id, user.id))
    return await _stream_file(request, song.filepath)

@router.get("/img/thumbnail/{image_hash}")
async def get_thumbnail(image_hash: str):
    path = os.path.join(settings.CACHE_DIR, f"{image_hash}.webp")
    if os.path.exists(path):
        from fastapi.responses import FileResponse
        return FileResponse(path, media_type="image/webp")
    return Response(status_code=204)

@router.get("/img/artist/small/{image_hash}")
async def get_artist_image(image_hash: str):
    path = os.path.join(settings.CACHE_DIR, f"{image_hash}.webp")
    if os.path.exists(path):
        from fastapi.responses import FileResponse
        return FileResponse(path, media_type="image/webp")
    return Response(status_code=204)

@router.get("/img/playlist/{playlist_id}")
async def get_playlist_image(playlist_id: str):
    path = os.path.join(settings.CACHE_DIR, f"playlist_{playlist_id}.webp")
    if os.path.exists(path):
        from fastapi.responses import FileResponse
        return FileResponse(path, media_type="image/webp")
    return Response(status_code=204)

async def _record_play(song_id: int, user_id: int):
    try:
        from ..database import AsyncSessionLocal
        from sqlalchemy import update
        from datetime import datetime
        async with AsyncSessionLocal() as db:
            db.add(PlayHistory(song_id=song_id, user_id=user_id))
            await db.execute(update(Song).where(Song.id == song_id)
                .values(play_count=Song.play_count + 1, last_played=datetime.utcnow()))
            await db.commit()
    except Exception as e:
        logger.debug(f"Scrobble error: {e}")
EOF
ok "app/routers/stream.py"

# ── app/routers/library.py (version compacte) ─────────────────────
cat > "$APPS_DIR/app/routers/library.py" << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from sqlalchemy.orm import selectinload
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from ..database import get_db, Song, Album, Artist, Playlist, PlaylistEntry, Favourite, User
from ..routers.auth import get_current_user
from ..scanner import make_hash

songs_router    = APIRouter()
albums_router   = APIRouter()
artists_router  = APIRouter()
search_router   = APIRouter()
playlists_router = APIRouter()

def _s(s: Song) -> dict:
    return {"trackhash": s.hash, "hash": s.hash, "title": s.title,
            "artist": s.artist.name if s.artist else "Inconnu",
            "artisthash": make_hash(s.artist.name) if s.artist else "",
            "album": s.album.title if s.album else "Inconnu",
            "albumhash": s.album.hash if s.album else "",
            "duration": s.duration, "track": s.track_number or 0,
            "filepath": s.filepath, "image": s.image_hash or s.hash,
            "format": s.format or "", "bitrate": s.bitrate or 0}

def _al(a: Album) -> dict:
    return {"albumhash": a.hash, "hash": a.hash, "title": a.title,
            "artist": a.artist.name if a.artist else "Inconnu",
            "artisthash": make_hash(a.artist.name) if a.artist else "",
            "date": str(a.year) if a.year else "", "count": a.track_count,
            "duration": a.duration, "image": a.hash}

def _ar(a: Artist) -> dict:
    return {"artisthash": make_hash(a.name), "hash": make_hash(a.name),
            "name": a.name, "image": f"{make_hash(a.name)}.webp",
            "albumcount": len(a.albums) if a.albums else 0,
            "trackcount": len(a.songs) if a.songs else 0}

def _pl(p: Playlist) -> dict:
    return {"id": str(p.id), "name": p.name, "description": p.description,
            "count": len(p.entries) if p.entries else 0,
            "trackcount": len(p.entries) if p.entries else 0,
            "extra": {"description": p.description}}

# SONGS
@songs_router.post("/folder")
async def get_folder(body: dict, db: AsyncSession = Depends(get_db),
                     user: User = Depends(get_current_user)):
    start = body.get("start", 0); limit = body.get("limit", 500)
    r = await db.execute(select(Song).options(selectinload(Song.artist),
        selectinload(Song.album)).offset(start).limit(limit))
    songs = r.scalars().all()
    favs_r = await db.execute(select(Favourite.song_id).where(Favourite.user_id == user.id))
    fav_ids = {f[0] for f in favs_r.all()}
    dicts = [_s(s) for s in songs]
    for d, s in zip(dicts, songs): d["is_favourite"] = s.id in fav_ids
    return {"tracks": dicts}

@songs_router.get("/getall/songs")
async def get_all_songs(start: int = 0, limit: int = 500,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    r = await db.execute(select(Song).options(selectinload(Song.artist),
        selectinload(Song.album)).offset(start).limit(limit))
    return {"items": [_s(s) for s in r.scalars().all()]}

# ALBUMS
@albums_router.get("/getall/albums")
async def get_albums(start: int = 0, limit: int = 200, sortby: str = "created_date",
    reverse: str = "1", db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user)):
    r = await db.execute(select(Album).options(selectinload(Album.artist))
        .offset(start).limit(limit))
    return {"items": [_al(a) for a in r.scalars().all()]}

@albums_router.get("/album/{album_hash}/tracks")
async def get_album_tracks(album_hash: str, db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user)):
    r = await db.execute(select(Album).where(Album.hash == album_hash))
    album = r.scalar_one_or_none()
    if not album: raise HTTPException(404, "Album introuvable")
    r2 = await db.execute(select(Song).options(selectinload(Song.artist),
        selectinload(Song.album)).where(Song.album_id == album.id)
        .order_by(Song.track_number))
    return {"tracks": [_s(s) for s in r2.scalars().all()]}

# ARTISTS
@artists_router.get("/getall/artists")
async def get_artists(start: int = 0, limit: int = 200,
    db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    r = await db.execute(select(Artist).options(selectinload(Artist.albums),
        selectinload(Artist.songs)).offset(start).limit(limit).order_by(Artist.name))
    return {"items": [_ar(a) for a in r.scalars().all()]}

@artists_router.get("/artist/{artist_hash}/tracks")
async def get_artist_tracks(artist_hash: str, db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user)):
    r = await db.execute(select(Artist))
    artist = next((a for a in r.scalars().all() if make_hash(a.name) == artist_hash), None)
    if not artist: raise HTTPException(404, "Artiste introuvable")
    r2 = await db.execute(select(Song).options(selectinload(Song.artist),
        selectinload(Song.album)).where(Song.artist_id == artist.id))
    return {"tracks": [_s(s) for s in r2.scalars().all()]}

@artists_router.get("/artist/{artist_hash}/albums")
async def get_artist_albums(artist_hash: str, db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user)):
    r = await db.execute(select(Artist))
    artist = next((a for a in r.scalars().all() if make_hash(a.name) == artist_hash), None)
    if not artist: raise HTTPException(404, "Artiste introuvable")
    r2 = await db.execute(select(Album).options(selectinload(Album.artist))
        .where(Album.artist_id == artist.id))
    return {"albums": [_al(a) for a in r2.scalars().all()]}

# SEARCH
@search_router.get("/search/")
async def search_songs(q: str, limit: int = 50,
    db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    query = f"%{q}%"
    r = await db.execute(select(Song).options(selectinload(Song.artist),
        selectinload(Song.album)).join(Artist, Song.artist_id == Artist.id, isouter=True)
        .join(Album, Song.album_id == Album.id, isouter=True)
        .where(or_(Song.title.ilike(query), Artist.name.ilike(query),
                   Album.title.ilike(query))).limit(limit))
    return {"tracks": [_s(s) for s in r.scalars().all()]}

@search_router.get("/search/top")
async def search_top(q: str, limit: int = 5,
    db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    query = f"%{q}%"
    sr = await db.execute(select(Song).options(selectinload(Song.artist),
        selectinload(Song.album)).join(Artist, Song.artist_id == Artist.id, isouter=True)
        .where(or_(Song.title.ilike(query), Artist.name.ilike(query))).limit(limit))
    ar = await db.execute(select(Album).options(selectinload(Album.artist))
        .where(Album.title.ilike(query)).limit(limit))
    arr = await db.execute(select(Artist).where(Artist.name.ilike(query)).limit(limit))
    return {"tracks": [_s(s) for s in sr.scalars().all()],
            "albums": [_al(a) for a in ar.scalars().all()],
            "artists": [_ar(a) for a in arr.scalars().all()]}

# PLAYLISTS
class PCreate(BaseModel): name: str; description: str = ""
class PUpdate(BaseModel): name: Optional[str] = None; description: Optional[str] = None
class TAdd(BaseModel): trackhashes: List[str]
class TRemove(BaseModel): trackhash: str; index: int
class TReorder(BaseModel): old_index: int; new_index: int

@playlists_router.get("/playlists")
async def get_playlists(db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)):
    r = await db.execute(select(Playlist).options(selectinload(Playlist.entries))
        .where(Playlist.owner_id == user.id).order_by(Playlist.updated_at.desc()))
    return {"data": [_pl(p) for p in r.scalars().all()]}

@playlists_router.get("/playlists/{playlist_id}")
async def get_playlist(playlist_id: int, db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)):
    r = await db.execute(select(Playlist).options(
        selectinload(Playlist.entries).selectinload(PlaylistEntry.song)
        .selectinload(Song.artist),
        selectinload(Playlist.entries).selectinload(PlaylistEntry.song)
        .selectinload(Song.album)).where(Playlist.id == playlist_id))
    p = r.scalar_one_or_none()
    if not p: raise HTTPException(404, "Playlist introuvable")
    if p.owner_id != user.id and not p.is_public: raise HTTPException(403, "Accès refusé")
    tracks = [_s(e.song) for e in sorted(p.entries, key=lambda e: e.position) if e.song]
    return {"info": _pl(p), "tracks": tracks}

@playlists_router.post("/playlists/new")
async def create_playlist(body: PCreate, db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)):
    p = Playlist(name=body.name, description=body.description, owner_id=user.id)
    db.add(p); await db.commit(); await db.refresh(p)
    return {"playlist": _pl(p)}

@playlists_router.post("/playlists/{playlist_id}/update")
async def update_playlist(playlist_id: int, body: PUpdate,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    p = await db.get(Playlist, playlist_id)
    if not p or p.owner_id != user.id: raise HTTPException(404, "Introuvable")
    if body.name is not None: p.name = body.name
    if body.description is not None: p.description = body.description
    p.updated_at = datetime.utcnow(); await db.commit()
    return {"ok": True}

@playlists_router.post("/playlists/{playlist_id}/delete")
async def delete_playlist(playlist_id: int, db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)):
    p = await db.get(Playlist, playlist_id)
    if not p or p.owner_id != user.id: raise HTTPException(404, "Introuvable")
    await db.delete(p); await db.commit()
    return {"ok": True}

@playlists_router.post("/playlists/{playlist_id}/add")
async def add_tracks(playlist_id: int, body: TAdd, db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)):
    p = await db.get(Playlist, playlist_id)
    if not p or p.owner_id != user.id: raise HTTPException(404, "Introuvable")
    r = await db.execute(select(func.max(PlaylistEntry.position))
        .where(PlaylistEntry.playlist_id == playlist_id))
    max_pos = r.scalar() or 0
    for i, h in enumerate(body.trackhashes):
        sr = await db.execute(select(Song).where(Song.hash == h))
        s = sr.scalar_one_or_none()
        if s: db.add(PlaylistEntry(playlist_id=playlist_id, song_id=s.id, position=max_pos+i+1))
    p.updated_at = datetime.utcnow(); await db.commit()
    return {"ok": True}

@playlists_router.post("/playlists/{playlist_id}/remove")
async def remove_track(playlist_id: int, body: TRemove, db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)):
    p = await db.get(Playlist, playlist_id)
    if not p or p.owner_id != user.id: raise HTTPException(404, "Introuvable")
    sr = await db.execute(select(Song).where(Song.hash == body.trackhash))
    song = sr.scalar_one_or_none()
    if song:
        er = await db.execute(select(PlaylistEntry)
            .where(PlaylistEntry.playlist_id == playlist_id)
            .where(PlaylistEntry.song_id == song.id))
        e = er.scalar_one_or_none()
        if e: await db.delete(e)
    await db.commit(); return {"ok": True}

@playlists_router.post("/playlists/{playlist_id}/reorder")
async def reorder_playlist(playlist_id: int, body: TReorder,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    p = await db.get(Playlist, playlist_id)
    if not p or p.owner_id != user.id: raise HTTPException(404, "Introuvable")
    r = await db.execute(select(PlaylistEntry)
        .where(PlaylistEntry.playlist_id == playlist_id)
        .order_by(PlaylistEntry.position))
    entries = list(r.scalars().all())
    if body.old_index < len(entries) and body.new_index < len(entries):
        e = entries.pop(body.old_index); entries.insert(body.new_index, e)
        for i, en in enumerate(entries): en.position = i
    await db.commit(); return {"ok": True}

# FAVOURITES
@songs_router.get("/favourites")
async def get_favourites(db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)):
    r = await db.execute(select(Favourite).options(
        selectinload(Favourite.song).selectinload(Song.artist),
        selectinload(Favourite.song).selectinload(Song.album))
        .where(Favourite.user_id == user.id).order_by(Favourite.added_at.desc()))
    return {"tracks": [_s(f.song) for f in r.scalars().all() if f.song]}

@songs_router.post("/track/favourite")
async def toggle_favourite(body: dict, db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)):
    sr = await db.execute(select(Song).where(Song.hash == body.get("trackhash", "")))
    song = sr.scalar_one_or_none()
    if not song: raise HTTPException(404, "Titre introuvable")
    fr = await db.execute(select(Favourite).where(Favourite.user_id == user.id,
        Favourite.song_id == song.id))
    fav = fr.scalar_one_or_none()
    if fav: await db.delete(fav); action = "removed"
    else: db.add(Favourite(user_id=user.id, song_id=song.id)); action = "added"
    await db.commit(); return {"action": action}
EOF
ok "app/routers/library.py"

# ── app/routers/extras.py (lyrics + stats + scan + users) ────────
cat > "$APPS_DIR/app/routers/extras.py" << 'EOF'
import httpx, logging
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from sqlalchemy.orm import selectinload
from datetime import datetime, timedelta
from ..database import get_db, Song, LyricsCache, PlayHistory, User, Artist, Album
from ..routers.auth import get_current_user, require_admin
from ..config import settings
from ..scanner import make_hash, scanner
from pydantic import BaseModel
from typing import Optional

lyrics_router = APIRouter()
stats_router  = APIRouter()
scan_router   = APIRouter()
users_router  = APIRouter()

# LYRICS
class LyricsReq(BaseModel): trackhash: str; filepath: str = ""

@lyrics_router.post("/lyrics")
async def get_lyrics(body: LyricsReq, db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user)):
    r = await db.execute(select(Song).where(Song.hash == body.trackhash))
    song = r.scalar_one_or_none()
    if not song: raise HTTPException(404, "Titre introuvable")
    cr = await db.execute(select(LyricsCache).where(LyricsCache.song_id == song.id))
    cache = cr.scalar_one_or_none()
    if cache and cache.content:
        age = (datetime.utcnow() - cache.cached_at).days
        if age < settings.LYRICS_CACHE_DAYS:
            return {"lyrics": cache.content, "synced": cache.synced}
    result = await _fetch_lrclib(song.title,
        song.artist.name if song.artist else "",
        song.album.title if song.album else "", song.duration)
    if result:
        if cache:
            cache.content = result["content"]; cache.synced = result["synced"]; cache.cached_at = datetime.utcnow()
        else:
            db.add(LyricsCache(song_id=song.id, content=result["content"],
                               synced=result["synced"], source="lrclib"))
        await db.commit()
        return {"lyrics": result["content"], "synced": result["synced"]}
    return {"error": "Paroles introuvables"}

async def _fetch_lrclib(title, artist, album, duration):
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            r = await client.get(f"{settings.LRCLIB_BASE}/get",
                params={"track_name": title, "artist_name": artist,
                        "album_name": album, "duration": duration})
            if r.status_code == 200:
                d = r.json()
                if d.get("syncedLyrics"):
                    return {"content": d["syncedLyrics"], "synced": True}
                elif d.get("plainLyrics"):
                    return {"content": d["plainLyrics"], "synced": False}
    except: pass
    return None

# STATS
@stats_router.get("/stats/overview")
async def stats_overview(db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)):
    tp = await db.execute(select(func.count(PlayHistory.id)).where(PlayHistory.user_id == user.id))
    us = await db.execute(select(func.count(func.distinct(PlayHistory.song_id))).where(PlayHistory.user_id == user.id))
    tt = await db.execute(select(func.sum(Song.duration)).join(PlayHistory, PlayHistory.song_id == Song.id).where(PlayHistory.user_id == user.id))
    month = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0)
    tm = await db.execute(select(func.count(PlayHistory.id)).where(PlayHistory.user_id == user.id, PlayHistory.played_at >= month))
    return {"total_plays": tp.scalar() or 0, "unique_songs": us.scalar() or 0,
            "total_minutes": (tt.scalar() or 0) // 60, "this_month": tm.scalar() or 0}

@stats_router.get("/stats/top-tracks")
async def top_tracks(limit: int = 10, days: int = 30,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    since = datetime.utcnow() - timedelta(days=days)
    from .library import _s
    r = await db.execute(select(Song, func.count(PlayHistory.id).label("plays"))
        .join(PlayHistory, PlayHistory.song_id == Song.id)
        .where(PlayHistory.user_id == user.id, PlayHistory.played_at >= since)
        .options(selectinload(Song.artist), selectinload(Song.album))
        .group_by(Song.id).order_by(desc("plays")).limit(limit))
    return [{"song": _s(s), "plays": plays} for s, plays in r.all()]

@stats_router.get("/stats/top-artists")
async def top_artists(limit: int = 10, days: int = 30,
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    since = datetime.utcnow() - timedelta(days=days)
    r = await db.execute(select(Artist.name, func.count(PlayHistory.id).label("plays"))
        .join(Song, Song.artist_id == Artist.id)
        .join(PlayHistory, PlayHistory.song_id == Song.id)
        .where(PlayHistory.user_id == user.id, PlayHistory.played_at >= since)
        .group_by(Artist.id).order_by(desc("plays")).limit(limit))
    return [{"artist": name, "plays": plays} for name, plays in r.all()]

@stats_router.get("/stats/history")
async def play_history(limit: int = 50, db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)):
    from .library import _s
    r = await db.execute(select(PlayHistory)
        .options(selectinload(PlayHistory.song).selectinload(Song.artist),
                 selectinload(PlayHistory.song).selectinload(Song.album))
        .where(PlayHistory.user_id == user.id)
        .order_by(PlayHistory.played_at.desc()).limit(limit))
    return [{"song": _s(h.song), "played_at": h.played_at.isoformat()}
            for h in r.scalars().all() if h.song]

# SCAN
@scan_router.post("/scan/start")
async def start_scan(_: User = Depends(require_admin)):
    import asyncio
    if scanner.is_scanning: return {"status": "already_running"}
    asyncio.create_task(scanner.scan_all())
    return {"status": "started"}

@scan_router.get("/scan/status")
async def scan_status(_: User = Depends(get_current_user)):
    return {"scanning": scanner.is_scanning, **scanner.progress}

# USERS
class UserCreate(BaseModel): username: str; password: str; role: str = "user"

@users_router.get("/users/list")
async def list_users(db: AsyncSession = Depends(get_db), _: User = Depends(require_admin)):
    r = await db.execute(select(User))
    return [{"id": u.id, "username": u.username, "role": u.role,
             "is_active": u.is_active} for u in r.scalars().all()]

@users_router.post("/users/create")
async def create_user(body: UserCreate, db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin)):
    import bcrypt
    r = await db.execute(select(User).where(User.username == body.username))
    if r.scalar_one_or_none(): raise HTTPException(400, "Nom déjà pris")
    hashed = bcrypt.hashpw(body.password.encode(), bcrypt.gensalt()).decode()
    user = User(username=body.username, password=hashed, role=body.role)
    db.add(user); await db.commit(); await db.refresh(user)
    return {"id": user.id, "username": user.username, "role": user.role}
EOF
ok "app/routers/extras.py"

# ── app/main.py ───────────────────────────────────────────────────
cat > "$APPS_DIR/app/main.py" << 'EOF'
import asyncio, logging, os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from .database import init_db
from .config import settings

logging.basicConfig(level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🎵 AskariServer démarrage...")
    os.makedirs(settings.CACHE_DIR, exist_ok=True)
    await init_db()
    if settings.AUTO_SCAN_ON_START:
        from .scanner import LibraryScanner
        asyncio.create_task(LibraryScanner().scan_all())
    yield
    logger.info("🎵 AskariServer arrêt")

app = FastAPI(title="AskariServer", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"])

from .routers.auth    import router as auth_router
from .routers.library import (songs_router, albums_router, artists_router,
                               search_router, playlists_router)
from .routers.extras  import (lyrics_router, stats_router, scan_router, users_router)
from .routers.stream  import router as stream_router

app.include_router(auth_router,       prefix="/auth",   tags=["Auth"])
app.include_router(users_router,                        tags=["Users"])
app.include_router(songs_router,                        tags=["Songs"])
app.include_router(albums_router,                       tags=["Albums"])
app.include_router(artists_router,                      tags=["Artists"])
app.include_router(playlists_router,                    tags=["Playlists"])
app.include_router(search_router,                       tags=["Search"])
app.include_router(lyrics_router,                       tags=["Lyrics"])
app.include_router(stats_router,                        tags=["Stats"])
app.include_router(scan_router,                         tags=["Scan"])
app.include_router(stream_router,                       tags=["Stream"])

@app.get("/health", tags=["System"])
async def health(): return {"status": "ok", "version": "1.0.0"}

@app.get("/", tags=["System"])
async def root(): return {"name": "AskariServer", "version": "1.0.0",
    "status": "running", "docs": "/docs"}

@app.exception_handler(404)
async def not_found(req, exc): return JSONResponse({"error": "Non trouvé"}, 404)
EOF
ok "app/main.py"

# ════════════════════════════════════════════════════════════════════
#  BUILD DOCKER
# ════════════════════════════════════════════════════════════════════
echo ""
info "Build de l'image Docker (2-5 minutes)..."
cd "$APPS_DIR"
docker build -t askariserver:latest . 2>&1 | while IFS= read -r line; do
    echo "  $line"
done

if docker image inspect askariserver:latest &>/dev/null; then
    ok "Image Docker construite avec succès"
else
    error "Échec du build Docker"
fi

# ════════════════════════════════════════════════════════════════════
#  DÉMARRAGE
# ════════════════════════════════════════════════════════════════════
echo ""
info "Démarrage d'AskariServer..."
docker compose -f "$APPS_DIR/docker-compose.yml" up -d

sleep 5
if curl -sf http://localhost:7777/health &>/dev/null; then
    ok "AskariServer est en ligne sur le port 7777"
else
    warn "Le serveur démarre encore... vérifier avec : docker logs askariserver"
fi

# ════════════════════════════════════════════════════════════════════
#  RÉSUMÉ
# ════════════════════════════════════════════════════════════════════
NAS_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "IP_NAS")
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ AskariServer installé avec succès !           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e " 🌐 API      : ${BLUE}http://$NAS_IP:7777${NC}"
echo -e " 📖 Docs     : ${BLUE}http://$NAS_IP:7777/docs${NC}"
echo -e " 🎵 Musique  : ${MUSIC_DIR}"
echo -e " 💾 Données  : ${DATA_DIR}"
echo ""
echo -e "${YELLOW}══ Étape suivante : créer votre compte admin ══${NC}"
echo ""
echo "  curl -X POST http://$NAS_IP:7777/auth/setup \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"username\": \"admin\", \"password\": \"VOTRE_MOT_DE_PASSE\"}'"
echo ""
echo -e "${YELLOW}══ Puis pointer AskaSound sur : http://$NAS_IP:7777 ══${NC}"
echo ""

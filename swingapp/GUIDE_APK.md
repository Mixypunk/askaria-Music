# 📱 Guide — Obtenir ton APK SwingApp

## Étapes pour avoir ton APK en 5 minutes

---

### ÉTAPE 1 — Créer un compte GitHub (si tu n'en as pas)
👉 https://github.com/signup  
C'est gratuit.

---

### ÉTAPE 2 — Créer un nouveau dépôt
1. Va sur https://github.com/new
2. Nom du dépôt : `swingapp` (ou ce que tu veux)
3. Laisse tout par défaut
4. Clique **"Create repository"**

---

### ÉTAPE 3 — Uploader les fichiers
Sur la page de ton dépôt vide, clique **"uploading an existing file"**

Glisse-dépose **tout le contenu du dossier `swingapp`** (le dossier extrait du ZIP) :
- `.github/`
- `android/`
- `lib/`
- `pubspec.yaml`
- `README.md`
- `.gitignore`

Clique **"Commit changes"**

---

### ÉTAPE 4 — Regarder le build se faire
1. Va dans l'onglet **"Actions"** de ton dépôt
2. Tu verras le workflow **"Build SwingApp APK"** tourner (environ 5-8 minutes)
3. Une icône jaune = en cours, verte = fini ✅, rouge = erreur

---

### ÉTAPE 5 — Télécharger l'APK
**Option A — Via les Releases (recommandé) :**
1. Va dans **"Releases"** (barre latérale droite)
2. Clique sur la dernière release
3. Télécharge `app-release.apk`

**Option B — Via les Artifacts :**
1. Clique sur le workflow terminé dans "Actions"
2. En bas de la page, clique **"SwingApp-release"**
3. Télécharge le ZIP → extrais l'APK

---

### ÉTAPE 6 — Installer sur Android
1. Transfère l'APK sur ton téléphone (USB, email, Google Drive...)
2. Ouvre le fichier APK
3. Android va demander d'autoriser les "sources inconnues" → accepte
4. L'app s'installe !

---

## 🔧 Pour modifier l'app plus tard

Modifie les fichiers directement sur GitHub et un nouveau build se lance automatiquement !

---

## ❓ En cas de problème

Si le build échoue (croix rouge dans Actions) :
- Clique sur le workflow
- Clique sur "build-apk" 
- Lis les logs en rouge pour voir l'erreur
- Contacte-moi avec le message d'erreur

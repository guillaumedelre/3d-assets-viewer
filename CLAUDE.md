# CLAUDE.md

Guide pour travailler dans ce dépôt. Pour la présentation produit (fonctionnalités, captures), voir `README.md`.

## Le projet

**3D Assets Viewer** — un explorateur de modèles 3D façon explorateur Windows, écrit en **GDScript**
sur **Godot 4.7** (Forward Plus). On pointe vers un dossier du disque, on navigue dans l'arborescence,
et on prévisualise les modèles (`.glb` / `.gltf` / `.fbx` / `.obj`) : miniatures « brûlées » dans une
grille + aperçu 3D orbital. Toute l'UI est construite **par code** (pas de gros `.tscn`).

## Lancer / tester / builder

- **Ouvrir & lancer** : ouvrir `project.godot` dans Godot 4.7, puis **F5** (scène principale
  `scenes/main.tscn`, qui n'est qu'une racine `Control` déléguant à `scripts/main.gd`).
- **Tests** (GdUnit4, addon commité dans `addons/gdUnit4/`) :
  ```powershell
  pwsh tests/run.ps1
  ```
  La CI les rejoue à chaque push/PR (`.github/workflows/tests.yml`).
- **Build** : jamais à la main. Voir « Releases » ci-dessous. Pour un build de test sans publier :
  onglet **Actions → build → Run workflow**.

## Architecture (`scripts/`)

| Fichier | Rôle |
|---|---|
| `main.gd` | Fenêtre principale : barre d'outils, historique de navigation, assemblage de l'UI, **barre de statut** (chemin \| nb d'éléments \| version). |
| `folder_tree.gd` | Arbre de dossiers du volet gauche (lazy, `class_name FolderTree`). |
| `asset_grid.gd` | Grille de fichiers + miniatures (`class_name AssetGrid`, expose `entry_count`). |
| `model_preview.gd` | Aperçu 3D orbital du volet droit + panneau d'infos. |
| `model_loader.gd` | Chargement multi-format glTF/FBX/OBJ au runtime (`class_name ModelLoader`). |
| `thumbnail_baker.gd` | Rendu hors-écran + cache disque des miniatures (`user://thumbnails/`). |
| `version.gd` | `AppVersion.VERSION` — **généré par release-please**, ne pas éditer à la main. |

## Conventions & pièges

- **Découverte des `class_name`** : Godot ne les enregistre qu'après un import. En CI, chaque job fait
  d'abord `godot --headless --editor --quit --path .` avant tests/export ; sans ça → « Identifier not found ».
- **Godot 4.7 headless plante parfois au teardown** APRÈS un run/export réussi. Les workflows ignorent
  donc le code de sortie du process et vérifient le vrai verdict (fichiers produits / « Exit code: » de GdUnit).
- **Export macOS** : nécessite `application/bundle_identifier` dans `export_presets.cfg` (format reverse-DNS)
  et se construit sur un runner **macOS natif** (le cross-export depuis Linux est instable).
- **UI par code** : pour modifier l'interface, éditer `_build_ui()` dans `main.gd`, pas un `.tscn`.

## Commits & releases (IMPORTANT)

Dépôt en **Conventional Commits**. La version SemVer, le tag `vX.Y.Z`, le `CHANGELOG.md` et la
GitHub Release (avec les `.zip` Linux/Windows/macOS) sont produits **automatiquement** par
`release-please` (`.github/workflows/release.yml`) — **ne jamais choisir de version ni poser de tag à la main**.

Flux : push sur `main` → release-please tient à jour une « Release PR » → quand elle est fusionnée →
tag + Release + build des 3 plateformes. Ici, **tout type de commit** (feat, fix, perf, refactor, docs,
test, build, ci…) déclenche une release ; seuls `chore` et `style` sont silencieux.

Rédige chaque commit selon la règle complète :
@.claude/rules/conventional-commits.md

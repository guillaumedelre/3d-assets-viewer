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

## Workflow de contribution (IMPORTANT)

`main` est **protégée** : interdiction de pousser directement dessus. Tout changement passe par une PR.

1. Créer une branche : `git switch -c feat/ma-fonctionnalite` (préfixe libre : `feat/`, `fix/`, `chore/`…).
2. Committer sur la branche (messages WIP tolérés — ce ne sont pas eux qui pilotent la version).
3. Ouvrir une PR vers `main`. Le check **GdUnit4** doit être au vert : c'est **requis** pour fusionner.
4. **Squash-merge** avec un **titre de PR au format Conventional Commits** (`feat: …`, `fix: …`) : ce titre
   devient l'unique commit sur `main` et **pilote la version**. La branche est supprimée automatiquement.

Le dépôt n'autorise que le **squash merge** (historique linéaire) : une PR = un commit conventionnel sur `main`.

## Versioning & releases (automatique)

Conventional Commits → SemVer via **release-please** (`.github/workflows/release.yml`), jamais à la main.
Après un merge sur `main`, release-please tient à jour une « Release PR » (version + `CHANGELOG.md`) qui
**s'auto-fusionne** dès que le check GdUnit4 est vert → tag `vX.Y.Z` + GitHub Release + `.zip`
Linux/Windows/macOS. Publication automatique (repose sur le secret `ASSETS_3D_VIEWER_RELEASE_PLEASE_TOKEN`, cf. `release.yml`).
Ici **tout type de commit** (feat, fix, perf, refactor, docs, test, build, ci…) déclenche une release ;
seuls `chore` et `style` sont silencieux.

Règle de rédaction complète des commits / titres de PR :
@.claude/rules/conventional-commits.md

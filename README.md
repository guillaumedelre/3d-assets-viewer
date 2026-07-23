# 3D Assets Viewer

Un visualiseur d'assets 3D façon **explorateur Windows**, fait avec **Godot 4.7**. On pointe vers
n'importe quel dossier du disque, on navigue dans l'arborescence, et on prévisualise les modèles 3D
en temps réel — miniatures « brûlées » dans la grille et aperçu 3D orbital à droite.

## ✨ Fonctionnalités

- **Navigation type explorateur** : arbre de dossiers à gauche (Accueil + lecteurs), grille de fichiers
  au centre, volet d'aperçu 3D à droite. Barre d'outils Précédent / Suivant / Parent, champ de chemin,
  sélecteur de dossier natif, et bouton pour masquer l'aperçu.
- **Formats supportés au runtime** : `.glb`, `.gltf`, `.fbx` (moteur ufbx intégré, **FBX Unity compris**)
  et `.obj` (parseur maison avec matériaux `.mtl`).
- **Miniatures 3D** rendues hors-écran et **mises en cache sur disque** (`user://thumbnails/`) :
  générées une fois, instantanées ensuite.
- **Aperçu 3D interactif** : glisser pour pivoter, molette pour zoomer, cadrage caméra automatique, et un
  **tableau d'informations** (taille, maillages, sommets, dimensions).

## 🎮 Prise en main

1. Ouvrir **Godot 4.7** et importer `project.godot`.
2. Lancer la scène principale (**F5**).
3. Cliquer **« Ouvrir un dossier… »** et pointer vers un dossier contenant des modèles 3D.
4. Cliquer un fichier pour l'afficher à droite ; **glisser** pour pivoter, **molette** pour zoomer.

## 🧱 Structure

```
scenes/main.tscn        # racine minimale -> scripts/main.gd
scripts/
  main.gd               # barre d'outils, historique, navigation
  folder_tree.gd        # arbre de dossiers (volet gauche, lazy)
  asset_grid.gd         # grille de fichiers + miniatures
  model_preview.gd      # aperçu 3D orbital (volet droit)
  model_loader.gd       # chargement multi-format (glTF/FBX/OBJ)
  thumbnail_baker.gd    # rendu + cache des miniatures
icons/                  # icônes SVG (dossier, disque, accueil, modèle, aperçu)
theme.tres              # thème global (taille de police 14)
tests/                  # suite GdUnit4 (voir tests/README.md)
export_presets.cfg      # presets d'export Linux / Windows / macOS
```

## 🧪 Tests

Suite [GdUnit4](https://github.com/MikeSchulze/gdUnit4) headless (addon commité dans `addons/gdUnit4/`).

```powershell
pwsh tests/run.ps1
```

La CI ([`.github/workflows/tests.yml`](.github/workflows/tests.yml)) exécute la suite à chaque push/PR
sur `main`. Voir [`tests/README.md`](tests/README.md).

## 📦 Builds

[`.github/workflows/build.yml`](.github/workflows/build.yml) exporte l'application pour **Linux**,
**Windows** (cross-export depuis Ubuntu) et **macOS** (runner natif), en Godot 4.7 headless.

- Déclenchement manuel : onglet **Actions → build → Run workflow**.
- Sur un tag `v*` (ex. `v1.0.0`) : une **GitHub Release** est créée avec les `.zip` des trois plateformes.

## 🛠️ Prérequis

- **Godot 4.7** (les formats FBX/glTF/OBJ sont chargés à l'exécution, sans outil externe).
- Pour la CI/les builds : rien à installer localement — les workflows téléchargent Godot et les templates.

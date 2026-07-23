# Tests (GdUnit4)

Suite de tests headless pour le visualiseur, propulsée par [GdUnit4](https://github.com/MikeSchulze/gdUnit4)
(addon commité dans `res://addons/gdUnit4/`).

## Lancer les tests

**En local (Windows / PowerShell 7)** :

```powershell
pwsh tests/run.ps1                          # toute la suite
pwsh tests/run.ps1 res://tests/model_loader_test.gd   # une seule suite
```

Le binaire Godot est résolu via `-GodotBin`, puis `$env:GODOT_BIN`, sinon le défaut local
(`C:\Users\gdelr\Downloads\Godot_v4.7-stable_win64_console.exe`).

**Dans l'éditeur** : ouvre le projet, le panneau *GdUnit4* liste et exécute les suites.

**En CI** : le workflow [`.github/workflows/tests.yml`](../.github/workflows/tests.yml) exécute la suite
à chaque push/PR sur `main` et publie le rapport JUnit.

## Contenu

- `model_loader_test.gd` — détection de format (`ModelLoader.is_supported`), disponibilité runtime du FBX,
  et parseur OBJ : triangulation des quads, normales du fichier, **inversion du winding** (normales
  générées orientées vers le haut), matériaux double-face, indices négatifs, fichier manquant → `null`.

Les fixtures OBJ sont écrites à la volée dans `user://` (pas de fichiers importés par l'éditeur).

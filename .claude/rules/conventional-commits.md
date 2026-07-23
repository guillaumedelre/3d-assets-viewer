# Règle : Conventional Commits

Ce dépôt versionne **automatiquement** via [Conventional Commits](https://www.conventionalcommits.org/).
La SemVer et les releases sont calculées par la pipeline (`release-please`) — **on ne choisit jamais
le numéro de version à la main**. Le message de commit *est* la source de vérité de la version.

## Format

```
<type>[scope optionnel][!] : <description courte à l'impératif, minuscule, sans point final>

[corps optionnel, explique le POURQUOI]

[footer optionnel : BREAKING CHANGE: …, Refs: #123, Release-As: …]
```

Exemples : `feat(preview): ajoute le zoom à la molette` · `fix: corrige le cache de miniatures`.

## Types autorisés et effet sur la version

| Type        | Rôle                                            | Bump SemVer |
|-------------|-------------------------------------------------|-------------|
| `feat`      | nouvelle fonctionnalité                         | **minor** (`0.1.0`) |
| `fix`       | correction de bug                               | **patch** (`0.0.1`) |
| `perf`      | amélioration de performance                     | patch       |
| `refactor`  | refactorisation sans changement de comportement | patch       |
| `docs`      | documentation seulement                         | aucun*      |
| `test`      | ajout/màj de tests                              | aucun*      |
| `build`     | système de build, export presets, dépendances   | aucun*      |
| `ci`        | workflows GitHub Actions                        | aucun*      |
| `chore`     | tâches diverses (sans impact runtime)           | aucun*      |
| `style`     | formatage, sans impact sur le code              | aucun*      |

\* n'incrémente pas la version, mais apparaît quand même dans le CHANGELOG (sauf `chore`/`style`
souvent masqués). Un release n'est déclenché que s'il y a au moins un `feat`/`fix`/`perf`/breaking
depuis la dernière version.

## Changements cassants (major)

Deux façons équivalentes, qui déclenchent un bump **major** (`1.0.0`, `2.0.0`, …) :

1. Un `!` après le type/scope :
   ```
   feat(loader)!: retire le support du format .3ds
   ```
2. Un footer `BREAKING CHANGE:` :
   ```
   feat: nouvelle API de chargement

   BREAKING CHANGE: ModelLoader.load() prend désormais un dictionnaire d'options.
   ```

## Scope (Godot)

Optionnel mais recommandé — cible le module concerné :
`main`, `tree`, `grid`, `preview`, `loader`, `thumbnails`, `ui`, `tests`, `ci`, `export`.

## Forcer une version précise (utile pour la 1ʳᵉ release)

Le dépôt démarre à `0.0.0`. Par défaut, le 1ᵉʳ `feat:` donnera `0.1.0`. Pour publier directement
un numéro choisi (ex. la toute première version en `1.0.0`), ajoute un footer :

```
feat: première version publique

Release-As: 1.0.0
```

## Rappels

- Une idée = un commit (garde les commits atomiques et bien typés).
- La description reste courte et à l'impératif présent ; détaille le *pourquoi* dans le corps.
- Pas besoin de créer de tag `git tag` : la pipeline s'en charge quand la **Release PR** est fusionnée.
- En cas de doute sur le type, `fix` (patch) est plus sûr que `feat` (minor) pour un simple correctif.

class_name AppVersion
extends RefCounted

# Numéro de version SemVer de l'application, lu au runtime (barre de statut, etc.).
# Mis à jour AUTOMATIQUEMENT par release-please via le marqueur `x-release-please-version`
# (voir release-please-config.json > "extra-files"). Ne pas éditer à la main.
const VERSION := "1.1.0" # x-release-please-version

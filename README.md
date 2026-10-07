# AI Code-Review (Drupal) — Claude Code Skill

Dieses Repository ist ein **Claude Code Skill** für **KI-unterstützte Code-Reviews in
Drupal-Projekten**. Ziel ist eine konsistente Architektur, klare Verantwortlichkeiten und
verlässliche Review-Ergebnisse, um Wartbarkeit und Zuverlässigkeit zu fördern.

## Was es ist

- Ein global installierbarer **Skill** für Claude Code (`drupal-review`)
- **Review-Anweisungen** für KI-Code-Reviews (`rules/REVIEW.md`)
- Ein **Kontext-Generator** (`generate_context.sh`), der die nötigen Informationen bereitstellt:
  - PR-Kontext (Beschreibung, Kommentare, offene Review-Threads)
  - Diff je Datei mit Zeilennummern, dazu ein Index aller geänderten Dateien
  - File-Tree der berührten Module und Themes
  - die Development-Standards, gegen die geprüft wird — standardmäßig
    [`Effective-Bytes/development-standards`](https://github.com/Effective-Bytes/development-standards),
    umstellbar auf eigene (siehe *Eigene Standards verwenden*)

## Was es tut

- Definiert, **wie Drupal-Code strukturiert und geprüft wird**
- Stellt sicher, dass **Architektur- und Projektstandards eingehalten werden**
- Erzeugt Kontextdaten für präzise KI-Reviews — in einem `.drupal-review/`-Verzeichnis
  **innerhalb des Projekts**, damit Claude Code die Dateien ohne Einzelfreigaben lesen kann.
  Das Verzeichnis wird automatisch über `.git/info/exclude` ignoriert (keine `.gitignore`-Änderung,
  kein Commit) — das Zielprojekt bleibt unverändert.

## Was es nicht tut

- **Es ändert keinen Code.** Der Reviewer meldet Verstöße mit Belegstelle und Begründung;
  Patches oder umgeschriebene Dateien liefert er bewusst nicht.
- **Es ersetzt keine Linter.** PHPCS, ESLint, Stylelint und die Testsuite laufen weiter in
  der CI. Geprüft wird, was ein Linter nicht sieht: Architektur, Schichtentrennung,
  Platzierung von Logik.
- **Es prüft nur, was im PR steht.** Ohne offenen Pull Request bzw. Merge Request für den
  aktuellen Branch bricht der Generator ab.
- **Es ist keine Sicherheitsprüfung.** Für Security-Reviews eignet es sich nicht.

---

## Setup (einmalig pro Maschine)

### Voraussetzungen

- **Claude Code** — [Docs](https://code.claude.com/docs/de/overview)
- **GitHub CLI (`gh`)** oder **GitLab CLI (`glab`)**, authentifiziert (siehe unten) — lädt Standards und PR-Kontext
- **`jq`** — für PR-Kommentare und Metadaten

#### GitHub (`gh`)

```bash
gh auth login
```

#### GitLab (`glab`)

Erstelle zunächst einen **Personal Access Token** mit den Scopes **`read_repository`** und
**`read_api`** (GitLab → User Settings → Access -> Personal access tokens).

Authentifiziere dann die CLI:

```bash
glab auth login
# -> Im jeweiligen projekt, damit die Instanz erkannt wird.
# -> Methode Token, dann den erstellten Token angeben.
```

### Installation

Klone dieses Repository in dein persönliches Claude-Code-Skills-Verzeichnis. Der
Zielordner muss exakt `drupal-review` heißen — der Skill referenziert sich darüber selbst:

```bash
git clone https://github.com/Effective-Bytes/drupal-review.git ~/.claude/skills/drupal-review
```

 Der Skill `drupal-review` ist nun überall verfügbar.

### Aktualisieren

```bash
git -C ~/.claude/skills/drupal-review pull
```

---

## Anwendung

1. Wechsle im Projekt auf den Branch, dessen Pull Request / Merge Request du prüfen willst
   - Bei GitLab / drupalcode.org muss es der branch im issue-fork sein!
   - (der Generator nutzt `gh pr view` / `gh pr diff` für GitHub bzw. `glab mr view` / `glab mr diff`
  für GitLab).
2. Starte Claude Code im Projekt und gib `/drupal-review` ein

Claude generiert Kontext und prüft die Änderungen gegen die aktuellen Standards.

## Ohne Claude Code

Führe den Generator direkt aus; er schreibt den Kontext nach `.drupal-review/` im Projekt und
gibt dessen Pfad als letzte Zeile aus (`DRUPAL_REVIEW_WORKDIR=…`):

```bash
~/.claude/skills/drupal-review/generate_context.sh
```

Übergib anschließend `rules/REVIEW.md` als Instruktionen sowie den Inhalt des ausgegebenen
Arbeitsverzeichnisses (`context/` und `development_standards/`) an deinen AI-Reviewer.

---

## Konfiguration

### Eigene Standards verwenden

Der Generator lädt die Standards als Tarball von GitHub. Welches Repository und welcher
Branch das ist, steuern zwei Umgebungsvariablen:

```bash
export STANDARDS_REPO="deine-org/deine-standards"   # Default: Effective-Bytes/development-standards
export STANDARDS_REF="main"                         # Default: main
```

Das Repository muss dieselbe Struktur haben wie das Standard-Repository, weil `SKILL.md`
den Reviewer gezielt dorthin schickt:

```
ki-reviewer/review-checkliste.md   die durchsetzbare Checkliste — was hier steht, wird geprüft
richtlinien/*.md                   die ausführlichen Richtlinien samt Begründung
```

Ein **öffentliches** Standards-Repository wird ohne Anmeldung geladen (`curl`), ein
**privates** über die angemeldete GitHub CLI (`gh`). Ohne Zugriff bricht der Generator mit
einer Fehlermeldung ab, und der Reviewer startet nicht — ohne Standards gibt es kein Review.

Die Standards sind auf **Deutsch** verfasst. Der Reviewer versteht sie in jeder Sprache,
aber wer eigene Richtlinien hinterlegt, sollte sie in einer Sprache schreiben, in der auch
das Team liest.

### Weitere GitLab-Instanzen

Der Provider wird am `origin`-Remote erkannt. Die bekannten Hosts stehen in
[`gitlab-instances.txt`](gitlab-instances.txt); eigene oder selbst gehostete Instanzen
kommen über eine Umgebungsvariable dazu, die die Liste **ergänzt**:

```bash
export GITLAB_INSTANCES="gitlab.example.com"
```

Wird der Host so nicht gefunden, fragt der Generator `glab` und `gh` direkt, ob sie das
Repository kennen. Notfalls lässt sich die Erkennung überstimmen:

```bash
generate_context.sh --provider gitlab
```

---

## Mitwirken

Fehlerberichte, Vorschläge und Pull Requests sind willkommen — siehe
[CONTRIBUTING.md](CONTRIBUTING.md).

## Lizenz

[Apache License 2.0](LICENSE).

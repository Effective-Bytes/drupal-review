# Mitwirken

Danke fürs Interesse. Dieses Repository ist bewusst klein gehalten: ein Kontext-Generator
in Bash, ein Satz Review-Anweisungen, sonst nichts. Beiträge sind willkommen, wenn sie
diese Schlankheit nicht opfern.

## Bevor du etwas schreibst

Leg ein **Issue** an und beschreibe das Problem oder den Vorschlag. Für Fehler,
Erweiterungen und technische Aufgaben liegen Vorlagen bereit. Bei kleinen Korrekturen —
Tippfehler, kaputte Links, offensichtliche Bugs — reicht direkt ein Pull Request.

Wichtig bei Fehlerberichten: **Ausgabe des Generators mitschicken**, nicht nur die
Beschreibung. `generate_context.sh` schreibt alles Relevante nach `stderr`.

## Was nicht ins Repository gehört

Dies ist ein öffentliches Repository. Nicht hinein gehören:

- **Kundennamen, interne Repository-Pfade, Ticketnummern** — auch nicht in Issues,
  Kommentaren oder Commit-Messages. GitHub gibt editierte Fassungen über die
  Edit-Historie weiter heraus; Umformulieren im Nachhinein bereinigt nichts.
- **Selbst gehostete oder kundeneigene GitLab-Instanzen** in `gitlab-instances.txt`.
  Die Datei ist für öffentliche, allgemein nutzbare Hosts. Eigene Instanzen kommen über
  die Umgebungsvariable `GITLAB_INSTANCES` dazu.
- **Zugangsdaten jeder Art.** Der Generator liest ausschliesslich, was die angemeldete
  CLI ihm gibt; er braucht keine Tokens im Repository.

## Code

- **Bash**, kompatibel zu dem, was auf macOS und in gängigen Linux-Containern liegt.
  Keine neuen Abhängigkeiten ohne guten Grund — aktuell sind es `git`, `gh` oder `glab`,
  `jq`, `tar`, `curl`.
- **Logik gehört nach `lib/`**, ein Thema pro Datei. `generate_context.sh` bleibt der
  Ablauf: sourcen, Provider bestimmen, Phasen aufrufen.
- **Kommentare und Bezeichner auf Englisch**, Dokumentation und Nutzerausgaben auf
  Deutsch — so ist der Bestand, und Mischformen machen es nicht besser.
- Vor dem Commit: `bash -n` über die geänderten Dateien, und
  [`shellcheck`](https://www.shellcheck.net/), wenn du es hast.

## Testen

Es gibt keine automatisierte Testsuite. Getestet wird gegen einen echten Pull Request:

```bash
# In einem Drupal-Projekt, auf einem Branch mit offenem PR / MR
~/.claude/skills/drupal-review/generate_context.sh
```

Prüfe danach, was unter `.drupal-review/context/` gelandet ist. Änderungen an der
Provider-Erkennung bitte **auf beiden Seiten** testen, GitHub und GitLab — die Pfade
unterscheiden sich deutlich.

Bei Änderungen an `rules/REVIEW.md` oder `SKILL.md` hilft nur der Vergleich: dasselbe PR
einmal mit alter und einmal mit neuer Fassung reviewen und die Ergebnisse
gegenüberstellen.

## Pull Requests

Ein PR pro Thema, mit Bezug auf das Issue. Beschreibe, **was** du geändert hast und
**warum** — und woran du geprüft hast, dass es funktioniert.

## Lizenz

Mit deinem Beitrag stimmst du zu, dass er unter der [Apache License 2.0](LICENSE)
veröffentlicht wird.

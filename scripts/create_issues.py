#!/usr/bin/env python3
"""Crea labels, milestones e issues en GitHub a partir de TICKETS.md.

Uso:
    python scripts/create_issues.py --repo usuario/flapo [--dry-run]

Requisitos: gh CLI autenticado (`gh auth login`).
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

TICKETS = Path(__file__).resolve().parent.parent / "TICKETS.md"

PHASE_NAMES = {
    "0": "Fase 0 — Preparación",
    "1": "Fase 1 — Diseño",
    "2": "Fase 2 — Prototipo jugable",
    "3": "Fase 3 — Game feel",
    "4": "Fase 4 — Arte",
    "5": "Fase 5 — Audio",
    "6": "Fase 6 — Persistencia y pulido",
    "7": "Fase 7 — Calidad",
    "8": "Fase 8 — CI/CD y exportación",
    "9": "Fase 9 — Publicación",
    "10": "Fase 10 — Retrospectiva",
}

LABEL_COLORS = {
    "area:code": "1d76db",
    "area:art": "d93f0b",
    "area:audio": "5319e7",
    "area:docs": "0e8a16",
    "area:ci": "fbca04",
    "area:qa": "b60205",
    "area:release": "006b75",
}

HEADER = re.compile(r"^### (T-\d+) · (.+)$")
META = re.compile(r"^labels:\s*(.+?)\s*·\s*estimate:\s*(\d+)\s*$")


def parse(path: Path):
    tickets, current = [], None
    for line in path.read_text(encoding="utf-8").splitlines():
        m = HEADER.match(line)
        if m:
            current = {"id": m.group(1), "title": m.group(2), "labels": [], "estimate": None, "body": []}
            tickets.append(current)
            continue
        if current is None:
            continue
        mm = META.match(line)
        if mm and current["estimate"] is None:
            current["labels"] = [l.strip() for l in mm.group(1).split(",")]
            current["estimate"] = int(mm.group(2))
            continue
        if line.startswith("## ") or line.strip() == "---":
            current = None
            continue
        current["body"].append(line)
    return tickets


def gh(args, dry):
    cmd = ["gh", *args]
    if dry:
        print(" ".join(repr(a) if " " in a else a for a in cmd))
        return
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0 and "already exists" not in r.stderr:
        print(r.stderr.strip(), file=sys.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    tickets = parse(TICKETS)
    if not tickets:
        sys.exit("No se han encontrado tickets en TICKETS.md")

    # Labels
    for name, color in LABEL_COLORS.items():
        gh(["label", "create", name, "--color", color, "--repo", a.repo, "--force"], a.dry_run)
    for n in PHASE_NAMES:
        gh(["label", "create", f"fase:{n}", "--color", "c5def5", "--repo", a.repo, "--force"], a.dry_run)
    for pts in sorted({t["estimate"] for t in tickets}):
        gh(["label", "create", f"estimate:{pts}", "--color", "ededed", "--repo", a.repo, "--force"], a.dry_run)

    # Milestones (gh no tiene subcomando: usar la API)
    for n, title in PHASE_NAMES.items():
        gh(["api", f"repos/{a.repo}/milestones", "-f", f"title={title}"], a.dry_run)

    # Issues
    for t in tickets:
        phase = next((l.split(":")[1] for l in t["labels"] if l.startswith("fase:")), None)
        body = "\n".join(t["body"]).strip() + f"\n\n_Estimación: {t['estimate']} pt · Ticket {t['id']}_"
        args = ["issue", "create", "--repo", a.repo,
                "--title", f"{t['id']} · {t['title']}",
                "--body", body,
                "--label", ",".join(t["labels"] + [f"estimate:{t['estimate']}"])]
        if phase in PHASE_NAMES:
            args += ["--milestone", PHASE_NAMES[phase]]
        gh(args, a.dry_run)
        print(f"{t['id']} ✓")


if __name__ == "__main__":
    main()

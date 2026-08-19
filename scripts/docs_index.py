#!/usr/bin/env python3
"""Índice de busca por seção para as docs do ganza. Só biblioteca padrão."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import sys
import time
from pathlib import Path

DEFAULT_GLOBS = ["docs/**/*.md", "*.md", ".claude/**/*.md"]
IGNORED_PARTS = {".git", ".docs-index", "node_modules", ".dart_tool", "build"}
DB_RELATIVE_PATH = ".docs-index/index.db"

HEADING_RE = re.compile(r"^(#{1,6})(?!#)\s+(.+?)\s*#*\s*$")
FENCE_RE = re.compile(r"^(```|~~~)")
LABEL_RE = re.compile(r"§\d+(?:\.\d+)*|#\d+|\b[A-Z]{1,4}-?\d+(?:[.\-]\d+)*\b")

SCHEMA = """
CREATE TABLE IF NOT EXISTS files (path TEXT PRIMARY KEY, sha TEXT NOT NULL);

CREATE TABLE IF NOT EXISTS sections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  path TEXT NOT NULL, heading TEXT NOT NULL, trail TEXT NOT NULL,
  level INTEGER NOT NULL, line_start INTEGER NOT NULL, line_end INTEGER NOT NULL,
  chars INTEGER NOT NULL, body TEXT NOT NULL, vec BLOB
);
CREATE INDEX IF NOT EXISTS sections_path ON sections(path);

CREATE VIRTUAL TABLE IF NOT EXISTS sections_fts USING fts5(
  trail, body, content='sections', content_rowid='id',
  tokenize='unicode61 remove_diacritics 2'
);

CREATE TABLE IF NOT EXISTS labels (
  label TEXT NOT NULL, path TEXT NOT NULL, line INTEGER NOT NULL,
  section_id INTEGER, defining INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS labels_label ON labels(label);
CREATE INDEX IF NOT EXISTS labels_path ON labels(path);
"""


def connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    gitignore = db_path.parent / ".gitignore"
    if not gitignore.exists():
        gitignore.write_text("*\n", encoding="utf-8")
    conn = sqlite3.connect(str(db_path), timeout=30)
    conn.execute("PRAGMA busy_timeout = 30000")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.executescript(SCHEMA)
    conn.commit()
    return conn


def with_retry(fn, retries: int = 6, base_delay: float = 0.2):
    for attempt in range(retries):
        try:
            return fn()
        except sqlite3.OperationalError as exc:
            if "locked" not in str(exc).lower() or attempt == retries - 1:
                raise
            time.sleep(base_delay * (2**attempt))


def discover_files(root: Path, globs: list[str]) -> list[Path]:
    matched: set[Path] = set()
    for pattern in globs:
        for candidate in root.glob(pattern):
            if not candidate.is_file():
                continue
            if IGNORED_PARTS & set(candidate.relative_to(root).parts):
                continue
            matched.add(candidate)

    real_first = sorted(matched, key=lambda p: (p.is_symlink(), str(p)))
    seen_targets: set[Path] = set()
    deduped = []
    for candidate in real_first:
        target = candidate.resolve()
        if target in seen_targets:
            continue
        seen_targets.add(target)
        deduped.append(candidate)
    return sorted(deduped)


def relpath(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def sha256_of(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_sections(text: str):
    lines = text.splitlines()
    total = len(lines)
    headings = []
    fenced = [False] * (total + 1)
    in_fence = False
    fence_marker = None
    for line_no, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not in_fence:
            m = FENCE_RE.match(stripped)
            if m:
                in_fence = True
                fence_marker = m.group(1)
                fenced[line_no] = True
                continue
        else:
            fenced[line_no] = True
            if stripped.startswith(fence_marker):
                in_fence = False
            continue
        heading_match = HEADING_RE.match(line)
        if heading_match:
            level = len(heading_match.group(1))
            title = heading_match.group(2).strip()
            headings.append((line_no, level, title))

    sections = []
    stack: list[tuple[int, str]] = []
    if headings and headings[0][0] > 1:
        preamble = "\n".join(lines[: headings[0][0] - 1]).strip()
        if preamble:
            sections.append(
                {
                    "heading": "(preâmbulo)",
                    "trail": "(preâmbulo)",
                    "level": 0,
                    "line_start": 1,
                    "line_end": headings[0][0] - 1,
                }
            )
    if not headings:
        stem = None
        sections.append(
            {
                "heading": "(arquivo sem heading)",
                "trail": "(arquivo sem heading)",
                "level": 0,
                "line_start": 1,
                "line_end": max(total, 1),
            }
        )
    else:
        for idx, (line_no, level, title) in enumerate(headings):
            while stack and stack[-1][0] >= level:
                stack.pop()
            stack.append((level, title))
            trail = " › ".join(t for _, t in stack)
            line_end = (
                headings[idx + 1][0] - 1 if idx + 1 < len(headings) else total
            )
            sections.append(
                {
                    "heading": title,
                    "trail": trail,
                    "level": level,
                    "line_start": line_no,
                    "line_end": max(line_end, line_no),
                }
            )

    for section in sections:
        body_lines = lines[section["line_start"] - 1 : section["line_end"]]
        section["body"] = "\n".join(body_lines)
        section["chars"] = len(section["body"])

    section_line_ranges = [
        (s["line_start"], s["line_end"]) for s in sections
    ]

    def section_index_for_line(line_no: int):
        for i, (start, end) in enumerate(section_line_ranges):
            if start <= line_no <= end:
                return i
        return None

    labels = []
    for line_no, line in enumerate(lines, start=1):
        if fenced[line_no]:
            continue
        for match in LABEL_RE.finditer(line):
            idx = section_index_for_line(line_no)
            if idx is None:
                continue
            defining = 1 if line_no == sections[idx]["line_start"] else 0
            labels.append((match.group(0), line_no, idx, defining))

    return sections, labels


def index_file(conn: sqlite3.Connection, root: Path, path: Path) -> None:
    rp = relpath(root, path)
    text = path.read_text(encoding="utf-8", errors="replace")
    sections, labels = parse_sections(text)

    def write():
        with conn:
            existing_ids = [
                row[0]
                for row in conn.execute(
                    "SELECT id FROM sections WHERE path = ?", (rp,)
                )
            ]
            if existing_ids:
                conn.executemany(
                    "DELETE FROM sections_fts WHERE rowid = ?",
                    [(sid,) for sid in existing_ids],
                )
            conn.execute("DELETE FROM labels WHERE path = ?", (rp,))
            conn.execute("DELETE FROM sections WHERE path = ?", (rp,))

            section_ids = []
            for s in sections:
                cur = conn.execute(
                    """INSERT INTO sections
                       (path, heading, trail, level, line_start, line_end, chars, body)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                    (
                        rp,
                        s["heading"],
                        s["trail"],
                        s["level"],
                        s["line_start"],
                        s["line_end"],
                        s["chars"],
                        s["body"],
                    ),
                )
                section_ids.append(cur.lastrowid)
                conn.execute(
                    "INSERT INTO sections_fts (rowid, trail, body) VALUES (?, ?, ?)",
                    (cur.lastrowid, s["trail"], s["body"]),
                )

            for label, line_no, section_idx, defining in labels:
                conn.execute(
                    """INSERT INTO labels (label, path, line, section_id, defining)
                       VALUES (?, ?, ?, ?, ?)""",
                    (label, rp, line_no, section_ids[section_idx], defining),
                )

            conn.execute(
                "INSERT INTO files (path, sha) VALUES (?, ?) "
                "ON CONFLICT(path) DO UPDATE SET sha = excluded.sha",
                (rp, sha256_of(path)),
            )

    with_retry(write)


def remove_file(conn: sqlite3.Connection, rp: str) -> None:
    def write():
        with conn:
            ids = [
                row[0]
                for row in conn.execute(
                    "SELECT id FROM sections WHERE path = ?", (rp,)
                )
            ]
            if ids:
                conn.executemany(
                    "DELETE FROM sections_fts WHERE rowid = ?",
                    [(sid,) for sid in ids],
                )
            conn.execute("DELETE FROM labels WHERE path = ?", (rp,))
            conn.execute("DELETE FROM sections WHERE path = ?", (rp,))
            conn.execute("DELETE FROM files WHERE path = ?", (rp,))

    with_retry(write)


def refresh(
    conn: sqlite3.Connection, root: Path, globs: list[str], force: bool = False
) -> dict:
    stats = {"indexed": 0, "updated": 0, "removed": 0, "unchanged": 0}
    disk_files = discover_files(root, globs)
    wanted = {relpath(root, p): p for p in disk_files}

    known = dict(conn.execute("SELECT path, sha FROM files"))
    for rp in list(known):
        if not (root / rp).exists():
            remove_file(conn, rp)
            stats["removed"] += 1

    for rp, path in wanted.items():
        sha = sha256_of(path)
        previous = known.get(rp)
        if previous is None:
            index_file(conn, root, path)
            stats["indexed"] += 1
        elif force or previous != sha:
            index_file(conn, root, path)
            stats["updated"] += 1
        else:
            stats["unchanged"] += 1

    return stats


def resolve_globs(cli_globs) -> list[str]:
    return cli_globs if cli_globs else list(DEFAULT_GLOBS)


def cmd_index(args, conn: sqlite3.Connection, root: Path) -> int:
    stats = refresh(conn, root, resolve_globs(args.glob), force=args.force)
    if not args.quiet:
        print(json.dumps(stats, ensure_ascii=False, indent=2))
    return 0


def build_match_query(raw_terms: list[str]) -> str | None:
    text = " ".join(raw_terms)
    tokens = re.findall(r"\w+", text, re.UNICODE)
    if not tokens:
        return None
    clauses = []
    for token in tokens:
        escaped = token.replace('"', '""')
        clauses.append(f'"{escaped}"*')
    return " ".join(clauses)


def cmd_search(args, conn: sqlite3.Connection, root: Path) -> int:
    if not args.no_refresh:
        refresh(conn, root, resolve_globs(args.glob))

    match_query = build_match_query(args.terms)
    if match_query is None:
        print(json.dumps([], ensure_ascii=False, indent=2))
        return 0

    sql = """
        SELECT s.path, s.trail, s.line_start, s.line_end, s.chars,
               bm25(sections_fts) AS rank,
               snippet(sections_fts, 1, '»', '«', ' … ', 16) AS trecho
        FROM sections_fts
        JOIN sections s ON s.id = sections_fts.rowid
        WHERE sections_fts MATCH ?
    """
    params: list = [match_query]
    if args.path:
        sql += " AND s.path LIKE ?"
        params.append(f"%{args.path}%")
    sql += " ORDER BY rank LIMIT ?"
    params.append(args.limit)

    rows = conn.execute(sql, params).fetchall()
    results = [
        {
            "path": path,
            "linhas": f"{line_start}-{line_end}",
            "secao": trail,
            "chars": chars,
            "trecho": trecho,
            "rank": round(rank, 4),
        }
        for path, trail, line_start, line_end, chars, rank, trecho in rows
    ]
    print(json.dumps(results, ensure_ascii=False, indent=2))
    return 0


def cmd_label(args, conn: sqlite3.Connection, root: Path) -> int:
    if not args.no_refresh:
        refresh(conn, root, resolve_globs(args.glob))

    sql = """
        SELECT l.path, l.line, l.defining, s.trail
        FROM labels l
        LEFT JOIN sections s ON s.id = l.section_id
        WHERE UPPER(l.label) = UPPER(?)
    """
    params: list = [args.label]
    if args.path:
        sql += " AND l.path LIKE ?"
        params.append(f"%{args.path}%")
    sql += " ORDER BY l.defining DESC, l.path, l.line"

    rows = conn.execute(sql, params).fetchall()
    results = [
        {
            "path": path,
            "linha": line,
            "definicao": bool(defining),
            "secao": trail,
        }
        for path, line, defining, trail in rows
    ]
    print(json.dumps(results, ensure_ascii=False, indent=2))
    return 0


def cmd_outline(args, conn: sqlite3.Connection, root: Path) -> int:
    if not args.no_refresh:
        refresh(conn, root, resolve_globs(args.glob))

    known_paths = [row[0] for row in conn.execute("SELECT DISTINCT path FROM files")]
    target = args.file.strip()
    matches = [p for p in known_paths if p == target]
    if not matches:
        matches = [p for p in known_paths if target in p]

    if not matches:
        print(json.dumps({"error": f"nenhum arquivo indexado casa com '{target}'"}), file=sys.stderr)
        return 1
    if len(matches) > 1:
        print(
            json.dumps(
                {"error": "mais de um arquivo casa com o termo", "candidatos": matches},
                ensure_ascii=False,
            ),
            file=sys.stderr,
        )
        return 1

    sql = "SELECT heading, trail, level, line_start, line_end, chars FROM sections WHERE path = ?"
    params: list = [matches[0]]
    if args.max_level is not None:
        sql += " AND level <= ?"
        params.append(args.max_level)
    sql += " ORDER BY line_start"

    rows = conn.execute(sql, params).fetchall()
    results = [
        {
            "heading": heading,
            "secao": trail,
            "nivel": level,
            "linhas": f"{line_start}-{line_end}",
            "chars": chars,
        }
        for heading, trail, level, line_start, line_end, chars in rows
    ]
    print(json.dumps({"path": matches[0], "outline": results}, ensure_ascii=False, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="docs_index.py")
    parser.add_argument("--root", default=".")
    parser.add_argument("--glob", action="append", default=None)
    sub = parser.add_subparsers(dest="command", required=True)

    p_index = sub.add_parser("index")
    p_index.add_argument("--force", action="store_true")
    p_index.add_argument("--quiet", action="store_true")
    p_index.set_defaults(func=cmd_index)

    p_search = sub.add_parser("search")
    p_search.add_argument("terms", nargs="+")
    p_search.add_argument("--limit", type=int, default=10)
    p_search.add_argument("--path")
    p_search.add_argument("--no-refresh", action="store_true")
    p_search.set_defaults(func=cmd_search)

    p_label = sub.add_parser("label")
    p_label.add_argument("label")
    p_label.add_argument("--path")
    p_label.add_argument("--no-refresh", action="store_true")
    p_label.set_defaults(func=cmd_label)

    p_outline = sub.add_parser("outline")
    p_outline.add_argument("file")
    p_outline.add_argument("--max-level", type=int, default=None)
    p_outline.add_argument("--no-refresh", action="store_true")
    p_outline.set_defaults(func=cmd_outline)

    return parser


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    db_path = root / DB_RELATIVE_PATH

    try:
        conn = connect(db_path)
    except sqlite3.OperationalError as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 1

    try:
        return args.func(args, conn, root)
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())

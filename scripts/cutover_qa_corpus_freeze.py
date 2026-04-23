#!/usr/bin/env python3
"""
cutover_qa_corpus_freeze.py — Layer 2 cutover QA corpus freeze.

Implements §3.4 step 3: export the last 30 days of wipe-set rows to a
dated JSON archive used as post-cutover QA reference.

Read-only. Wraps every query in a READ ONLY transaction.

Ground truth:
    audit/phase_5_section_3_cutover_policy.md
    audit/phase_5_section_3_amendment_1.md
    audit/phase_5_section_3_amendment_2.md
    supabase/manual/cutover/manifest.yaml

Contract source: Phase B2 prompt §0 (B1 contract inlined in chat history).
Refusal codes: 10, 11, 20, 21, 22, 30, 31, 50, 51, 52, 60, 61.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import decimal
import json
import os
import re
import sys
import uuid
from pathlib import Path

import psycopg
from psycopg import sql as psql
import yaml


SCRIPT_NAME = "cutover_qa_corpus_freeze"
EXPORT_VERSION = 1
SUPPORTED_MANIFEST_VERSION = 1
DEFAULT_MANIFEST_REL = Path("supabase/manual/cutover/manifest.yaml")
DEFAULT_OUTPUT_REL = Path("supabase/manual/cutover/exports")
WINDOW_DAYS = 30

TS_COL_PATTERN = re.compile(r"^(created_at|inserted_at|occurred_at|event_at|timestamp)$")
ACCEPTABLE_TS_TYPES = frozenset({
    "timestamp without time zone",
    "timestamp with time zone",
    "date",
})

# Sentinel for "include all rows" (override file value `null`).
INCLUDE_ALL = object()


# --- Logging + refusals --------------------------------------------------

def _log(tag: str, message: str) -> None:
    print(f"[{tag}] {message}", flush=True)


def _refuse(code: int, message: str) -> "NoReturn":
    print(f"[refuse] code={code} {message}", file=sys.stderr, flush=True)
    sys.exit(code)


# --- Path / manifest -----------------------------------------------------

def _find_repo_root(start: Path) -> Path | None:
    p = start.resolve()
    while True:
        if (p / ".git").exists():
            return p
        if p == p.parent:
            return None
        p = p.parent


def _resolve_paths(args) -> tuple[Path, Path]:
    repo_root = _find_repo_root(Path(__file__))
    if repo_root is None and not (args.manifest_path and args.output_root):
        _refuse(20, "Repo root not found (no .git ancestor); pass --manifest-path and --output-root.")
    manifest_path = Path(args.manifest_path) if args.manifest_path else repo_root / DEFAULT_MANIFEST_REL
    output_root = Path(args.output_root) if args.output_root else repo_root / DEFAULT_OUTPUT_REL
    return manifest_path, output_root


def _load_manifest(manifest_path: Path) -> dict:
    if not manifest_path.exists() or not manifest_path.is_file():
        _refuse(20, f"Manifest not found: {manifest_path}. Fix --manifest-path or restore manifest.")
    try:
        with manifest_path.open("r") as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        _refuse(20, f"Manifest YAML parse failed: {e}")
    except OSError as e:
        _refuse(20, f"Manifest read failed: {e}")
    if not isinstance(data, dict):
        _refuse(20, "Manifest top-level is not a YAML mapping.")
    if "schema_version" not in data:
        _refuse(21, "Manifest missing schema_version key. Add 'schema_version: 1'.")
    if data["schema_version"] != SUPPORTED_MANIFEST_VERSION:
        _refuse(21, f"Manifest schema_version={data['schema_version']} not supported (expected {SUPPORTED_MANIFEST_VERSION}).")
    return data


def _load_overrides(path: str | None) -> dict[str, object]:
    """
    Returns {table_fqn: column_name | INCLUDE_ALL}. Empty dict if path is None.
    """
    if path is None:
        return {}
    p = Path(path)
    if not p.exists() or not p.is_file():
        _refuse(20, f"--timestamp-overrides path does not exist: {p}")
    try:
        with p.open("r") as f:
            data = yaml.safe_load(f) or {}
    except yaml.YAMLError as e:
        _refuse(20, f"Override YAML parse failed: {e}")
    if not isinstance(data, dict) or "tables" not in data:
        _refuse(20, "Override file must contain top-level 'tables:' map.")
    tables = data["tables"]
    if not isinstance(tables, dict):
        _refuse(20, "Override 'tables' is not a mapping.")
    out: dict[str, object] = {}
    for k, v in tables.items():
        if v is None:
            out[str(k).strip()] = INCLUDE_ALL
        elif isinstance(v, str):
            out[str(k).strip()] = v
        else:
            _refuse(20, f"Override entry {k} value type {type(v).__name__} unsupported (string or null only).")
    return out


# --- Run timestamp / as-of -----------------------------------------------

def _run_timestamp_type(s: str) -> str:
    try:
        dt.datetime.strptime(s, "%Y%m%dT%H%M%SZ")
    except ValueError:
        raise argparse.ArgumentTypeError(
            f"'{s}' must match %Y%m%dT%H%M%SZ (e.g. 20260423T143000Z)"
        )
    return s


def _utc_now_compact() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _as_of_type(s: str) -> dt.datetime:
    try:
        d = dt.datetime.fromisoformat(s)
    except ValueError as e:
        raise argparse.ArgumentTypeError(f"'{s}' not parseable as ISO 8601: {e}")
    if d.tzinfo is None or d.tzinfo.utcoffset(d) is None:
        raise argparse.ArgumentTypeError(
            f"'{s}' is timezone-naive; must include offset (e.g. ...+00:00 or Z)"
        )
    return d.astimezone(dt.timezone.utc)


# --- Postgres helpers ----------------------------------------------------

def _connect_session(db_url: str, db_role: str | None = None) -> psycopg.Connection:
    try:
        conn = psycopg.connect(db_url, autocommit=True, application_name=SCRIPT_NAME)
    except psycopg.Error as e:
        _refuse(30, f"Connection failed: {e}. Check credentials/network.")
    try:
        with conn.cursor() as cur:
            cur.execute("SET statement_timeout = '60s';")
            cur.execute("SET lock_timeout = '5s';")
            if db_role:
                cur.execute(psql.SQL("SET ROLE {}").format(psql.Identifier(db_role)))
    except psycopg.Error as e:
        conn.close()
        _refuse(30, f"Session setup failed: {e}.")
    return conn


def _conn_target(conn: psycopg.Connection) -> tuple[str, str]:
    info = conn.info
    return (info.host or "<unknown-host>", info.dbname or "<unknown-db>")


def _columns_for_table(
    conn: psycopg.Connection, schema: str, table: str
) -> list[tuple[str, str]]:
    q = """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        ORDER BY ordinal_position
    """
    try:
        with conn.cursor() as cur:
            cur.execute("BEGIN READ ONLY;")
            cur.execute(q, (schema, table))
            rows = cur.fetchall()
            cur.execute("COMMIT;")
            return [(r[0], r[1]) for r in rows]
    except psycopg.Error as e:
        try:
            conn.rollback()
        except psycopg.Error:
            pass
        _refuse(31, f"Column introspection failed for {schema}.{table}: {e}")


def _primary_key_columns(conn: psycopg.Connection, schema: str, table: str) -> list[str]:
    q = """
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = (quote_ident(%s) || '.' || quote_ident(%s))::regclass
          AND i.indisprimary
        ORDER BY array_position(i.indkey::int[], a.attnum)
    """
    try:
        with conn.cursor() as cur:
            cur.execute("BEGIN READ ONLY;")
            cur.execute(q, (schema, table))
            rows = cur.fetchall()
            cur.execute("COMMIT;")
            return [r[0] for r in rows]
    except psycopg.Error as e:
        try:
            conn.rollback()
        except psycopg.Error:
            pass
        _refuse(31, f"PK introspection failed for {schema}.{table}: {e}")


def _resolve_timestamp_column(
    columns: list[tuple[str, str]],
    table_fqn: str,
    override: object,
) -> str | None:
    """
    Returns resolved timestamp column name, or None if include-all.
    Refuses (50) on missing/ambiguous when no override.
    Refuses (51) on invalid override.
    """
    by_name = {name: dtype for name, dtype in columns}
    candidates = [name for name in by_name if TS_COL_PATTERN.match(name)]

    if override is INCLUDE_ALL:
        return None
    if isinstance(override, str):
        if override not in by_name:
            _refuse(51, f"Override {table_fqn}={override}: column not found in table.")
        if by_name[override] not in ACCEPTABLE_TS_TYPES:
            _refuse(51, f"Override {table_fqn}={override}: non-temporal type ({by_name[override]}).")
        return override

    if len(candidates) == 1:
        return candidates[0]
    if len(candidates) == 0:
        _refuse(
            50,
            f"Table {table_fqn} timestamp column missing (no candidate among "
            f"{{created_at,inserted_at,occurred_at,event_at,timestamp}}). "
            f"Provide --timestamp-overrides or --exclude-table.",
        )
    _refuse(
        50,
        f"Table {table_fqn} timestamp column ambiguous: candidates={candidates}. "
        f"Provide --timestamp-overrides or --exclude-table.",
    )


def _windowed_count(
    conn: psycopg.Connection,
    schema: str,
    table: str,
    ts_col: str | None,
    start_dt: dt.datetime,
    end_dt: dt.datetime,
) -> int:
    if ts_col is None:
        q = psql.SQL("SELECT count(*) FROM {}.{}").format(
            psql.Identifier(schema), psql.Identifier(table)
        )
        params: tuple = ()
    else:
        q = psql.SQL("SELECT count(*) FROM {}.{} WHERE {} >= %s AND {} < %s").format(
            psql.Identifier(schema), psql.Identifier(table),
            psql.Identifier(ts_col), psql.Identifier(ts_col),
        )
        params = (start_dt, end_dt)
    try:
        with conn.cursor() as cur:
            cur.execute("BEGIN READ ONLY;")
            cur.execute(q, params)
            n = cur.fetchone()[0]
            cur.execute("COMMIT;")
            return int(n)
    except psycopg.Error as e:
        try:
            conn.rollback()
        except psycopg.Error:
            pass
        _refuse(31, f"Read-only count failed for {schema}.{table}: {e}")


# --- JSON serialization --------------------------------------------------

def _json_default(obj):
    if isinstance(obj, (dt.datetime, dt.date, dt.time)):
        return obj.isoformat()
    if isinstance(obj, dt.timedelta):
        return str(obj)
    if isinstance(obj, decimal.Decimal):
        return str(obj)
    if isinstance(obj, uuid.UUID):
        return str(obj)
    if isinstance(obj, (bytes, bytearray, memoryview)):
        return {"bytea_base64": base64.b64encode(bytes(obj)).decode("ascii")}
    raise TypeError(f"Object of type {obj.__class__.__name__} is not JSON serializable")


def _export_table(
    conn: psycopg.Connection,
    schema: str,
    table: str,
    ts_col: str | None,
    start_dt: dt.datetime,
    end_dt: dt.datetime,
    pk_cols: list[str],
    out_path: Path,
) -> int:
    if pk_cols:
        order_clause = psql.SQL(" ORDER BY ") + psql.SQL(", ").join(
            psql.Identifier(c) for c in pk_cols
        )
        row_order = "primary_key"
    else:
        order_clause = psql.SQL("")
        row_order = "unspecified"

    if ts_col is None:
        select_q = psql.SQL("SELECT * FROM {}.{}").format(
            psql.Identifier(schema), psql.Identifier(table)
        ) + order_clause
        params: tuple = ()
    else:
        select_q = psql.SQL("SELECT * FROM {}.{} WHERE {} >= %s AND {} < %s").format(
            psql.Identifier(schema), psql.Identifier(table),
            psql.Identifier(ts_col), psql.Identifier(ts_col),
        ) + order_clause
        params = (start_dt, end_dt)

    try:
        with conn.cursor() as cur:
            cur.execute("BEGIN READ ONLY;")
            cur.execute(select_q, params)
            col_names = [d.name for d in cur.description]
            rows = [{c: row[i] for i, c in enumerate(col_names)} for row in cur]
            cur.execute("COMMIT;")
    except psycopg.Error as e:
        try:
            conn.rollback()
        except psycopg.Error:
            pass
        _refuse(31, f"Read failed for {schema}.{table}: {e}")

    payload = {
        "export_version": EXPORT_VERSION,
        "script": SCRIPT_NAME,
        "manifest_schema_version": SUPPORTED_MANIFEST_VERSION,
        "table": f"{schema}.{table}",
        "exported_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "row_count": len(rows),
        "columns": col_names,
        "row_order": row_order,
        "window": {"start": start_dt.isoformat(), "end_exclusive": end_dt.isoformat()},
        "timestamp_column": ts_col,
        "rows": rows,
    }
    try:
        with out_path.open("w") as f:
            json.dump(payload, f, default=_json_default, ensure_ascii=False, indent=2)
    except (OSError, TypeError, ValueError) as e:
        _refuse(61, f"Write failed for {out_path}: {e}. No partial success claimed.")
    return len(rows)


# --- Main ----------------------------------------------------------------

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog=SCRIPT_NAME,
        description="Export 30-day window of wipe-set rows to JSON. Read-only.",
    )
    p.add_argument("--db-url", default=None, help="Libpq connection string. Overrides DATABASE_URL.")
    p.add_argument("--db-role", default=None, help="Optional database role to SET after connect (e.g. postgres).")
    p.add_argument("--confirm-live", action="store_true", help="Required affirmative flag for any DB connection.")
    p.add_argument("--manifest-path", default=None)
    p.add_argument("--output-root", default=None)
    p.add_argument("--run-timestamp", type=_run_timestamp_type, default=None,
                   help="ISO 8601 UTC compact (YYYYMMDDTHHMMSSZ). Default: now UTC.")
    p.add_argument("--dry-run", action="store_true", help="Validate + plan + report; no disk writes.")
    p.add_argument("--as-of", type=_as_of_type, default=None,
                   help="ISO 8601 timezone-aware datetime. Default: now UTC.")
    p.add_argument("--timestamp-overrides", default=None, help="YAML override file path.")
    p.add_argument("--exclude-table", action="append", default=[],
                   help="Schema-qualified table to exclude from the freeze. Repeatable.")
    return p


def main() -> None:
    args = _build_parser().parse_args()

    db_url = args.db_url or os.environ.get("DATABASE_URL", "")
    if not db_url:
        _refuse(10, "Provide DATABASE_URL env or --db-url flag.")

    if not args.confirm_live:
        host, db = "<unknown>", "<unknown>"
        try:
            with psycopg.connect(db_url, autocommit=True, connect_timeout=5) as tmp:
                host, db = _conn_target(tmp)
        except psycopg.Error:
            pass
        _refuse(11, f"Refusing target host={host} db={db}; re-run with --confirm-live.")

    manifest_path, output_root = _resolve_paths(args)
    manifest = _load_manifest(manifest_path)
    wipe = manifest.get("wipe", [])
    if not isinstance(wipe, list):
        _refuse(20, "Manifest 'wipe' is not a list.")

    overrides = _load_overrides(args.timestamp_overrides)
    excluded = set(args.exclude_table)

    # Conflict: same table both excluded AND has timestamp override.
    conflicts = excluded & set(overrides.keys())
    if conflicts:
        _refuse(
            52,
            f"Conflicting exclusion and timestamp override for {sorted(conflicts)}. "
            f"Operator decides explicitly: drop from --exclude-table or remove from override file.",
        )

    # Override sanity: every overridden table must exist in wipe set.
    wipe_fqns = {str(e["table"]).strip() for e in wipe if isinstance(e, dict) and "table" in e}
    for ovr_table in overrides:
        if ovr_table not in wipe_fqns:
            _refuse(51, f"Override {ovr_table}=...: table not in wipe set.")

    as_of = args.as_of or dt.datetime.now(dt.timezone.utc)
    start_dt = as_of - dt.timedelta(days=WINDOW_DAYS)

    run_timestamp = args.run_timestamp or _utc_now_compact()
    run_dir = output_root / run_timestamp
    out_subdir = run_dir / "qa_corpus"
    index_path = run_dir / "qa_corpus_index.json"

    conn = _connect_session(db_url, args.db_role)
    host, db = _conn_target(conn)

    mode = "dry-run" if args.dry_run else "real-run"
    _log(SCRIPT_NAME, f"mode={mode} target host={host} db={db}")
    _log("manifest", f"path={manifest_path} schema_version={manifest['schema_version']} wipe_entries={len(wipe)}")
    _log("window", f"as_of={as_of.isoformat()} start={start_dt.isoformat()} end_exclusive={as_of.isoformat()}")

    if not args.dry_run and (out_subdir.exists() or index_path.exists()):
        conn.close()
        _refuse(60, f"QA corpus output already exists under {run_dir}; choose a new --run-timestamp.")

    plans: list[tuple[str, str, str | None, int, str]] = []
    skipped_excluded: list[str] = []
    for i, entry in enumerate(wipe):
        if not isinstance(entry, dict) or "table" not in entry:
            conn.close()
            _refuse(22, f"Wipe entry index {i} missing required keys: ['table'].")
        sel = str(entry["table"]).strip()
        if sel in excluded:
            skipped_excluded.append(sel)
            _log("plan", f"{sel} excluded via --exclude-table")
            continue
        if "." not in sel:
            conn.close()
            _refuse(22, f"Wipe entry '{sel}' is not schema-qualified.")
        schema, table = sel.split(".", 1)
        cols = _columns_for_table(conn, schema, table)
        if not cols:
            conn.close()
            _refuse(31, f"Table {sel} returned no columns from information_schema.")
        ovr = overrides.get(sel)
        ts_col = _resolve_timestamp_column(cols, sel, ovr)
        n = _windowed_count(conn, schema, table, ts_col, start_dt, as_of)
        rel_file = f"qa_corpus/{schema}__{table}.json"
        plans.append((schema, table, ts_col, n, rel_file))
        _log("plan", f"{sel} timestamp_column={ts_col if ts_col else '<include-all>'} rows={n} file={rel_file}")

    total_rows = sum(p[3] for p in plans)
    _log("summary", f"planned_tables={len(plans)} planned_rows={total_rows} excluded={len(skipped_excluded)} output_run={run_timestamp} dry_run={str(args.dry_run).lower()}")

    if args.dry_run:
        _log("exit", "dry-run complete; no directories or JSON files written")
        conn.close()
        sys.exit(0)

    # Real run
    try:
        out_subdir.mkdir(parents=True, exist_ok=False)
    except FileExistsError:
        conn.close()
        _refuse(60, f"QA corpus output already exists under {run_dir}; choose a new --run-timestamp.")
    except OSError as e:
        conn.close()
        _refuse(61, f"mkdir failed for {out_subdir}: {e}.")

    files = []
    for schema, table, ts_col, _n_planned, rel_file in plans:
        pk_cols = _primary_key_columns(conn, schema, table)
        out_path = run_dir / rel_file
        n_written = _export_table(conn, schema, table, ts_col, start_dt, as_of, pk_cols, out_path)
        files.append({
            "table": f"{schema}.{table}",
            "path": rel_file,
            "row_count": n_written,
            "timestamp_column": ts_col,
        })
        _log("write", f"{schema}.{table} rows={n_written} -> {rel_file}")

    index = {
        "export_version": EXPORT_VERSION,
        "script": SCRIPT_NAME,
        "manifest_schema_version": SUPPORTED_MANIFEST_VERSION,
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "source": {"host": host, "database": db},
        "run_timestamp": run_timestamp,
        "window": {"start": start_dt.isoformat(), "end_exclusive": as_of.isoformat()},
        "files": files,
    }
    try:
        with index_path.open("w") as f:
            json.dump(index, f, default=_json_default, ensure_ascii=False, indent=2)
    except (OSError, TypeError, ValueError) as e:
        conn.close()
        _refuse(61, f"Write failed for {index_path}: {e}. No partial success claimed.")

    _log("done", f"index={index_path} tables_written={len(files)} rows_written={sum(f['row_count'] for f in files)}")
    conn.close()


if __name__ == "__main__":
    main()

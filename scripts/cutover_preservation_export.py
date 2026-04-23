#!/usr/bin/env python3
"""
cutover_preservation_export.py — Layer 2 cutover preservation export.

Implements §3.4 step 4: belt-and-braces JSON export of the §3.1
preservation set, used as the verification baseline for §3.4 step 6
post-wipe row-count re-check.

Read-only. Wraps every query in a READ ONLY transaction.

Ground truth:
    audit/phase_5_section_3_cutover_policy.md
    audit/phase_5_section_3_amendment_1.md
    audit/phase_5_section_3_amendment_2.md
    audit/phase_5_section_3_amendment_3.md
    supabase/manual/cutover/manifest.yaml

Contract source: Phase B2 prompt §0 (B1 contract inlined in chat history).
Refusal codes: see prompt §0.10 — partial set used by this script:
    10, 11, 20, 21, 22, 30, 31, 40, 60, 61.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import decimal
import json
import os
import sys
import uuid
from pathlib import Path

import psycopg
from psycopg import sql as psql
import yaml


SCRIPT_NAME = "cutover_preservation_export"
EXPORT_VERSION = 1
SUPPORTED_MANIFEST_VERSION = 1
DEFAULT_MANIFEST_REL = Path("supabase/manual/cutover/manifest.yaml")
DEFAULT_OUTPUT_REL = Path("supabase/manual/cutover/exports")


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


# --- Run timestamp -------------------------------------------------------

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


# --- Preservation entry classification -----------------------------------

def _classify_preservation_entry(entry: object) -> tuple[str, str]:
    """
    Returns (kind, selector). kind ∈ {"table","auth","malformed","other"}.
    """
    if not isinstance(entry, dict) or "table" not in entry:
        return ("malformed", "")
    sel = str(entry["table"]).strip()
    if sel.lower() == "auth.*":
        return ("auth", sel)
    if "." in sel and "*" not in sel:
        schema, table = sel.split(".", 1)
        if schema and table:
            return ("table", sel)
    return ("other", sel)


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


def _row_count(conn: psycopg.Connection, schema: str, table: str) -> int:
    q = psql.SQL("SELECT count(*) FROM {}.{}").format(
        psql.Identifier(schema), psql.Identifier(table)
    )
    try:
        with conn.cursor() as cur:
            cur.execute("BEGIN READ ONLY;")
            cur.execute(q)
            n = cur.fetchone()[0]
            cur.execute("COMMIT;")
            return int(n)
    except psycopg.Error as e:
        try:
            conn.rollback()
        except psycopg.Error:
            pass
        _refuse(31, f"Read-only count failed for {schema}.{table}: {e}")


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


# --- Real-run table export -----------------------------------------------

def _export_table(
    conn: psycopg.Connection,
    schema: str,
    table: str,
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
    q = psql.SQL("SELECT * FROM {}.{}").format(
        psql.Identifier(schema), psql.Identifier(table)
    ) + order_clause
    try:
        with conn.cursor() as cur:
            cur.execute("BEGIN READ ONLY;")
            cur.execute(q)
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
        description="Export §3.1 preservation set to JSON. Read-only.",
    )
    p.add_argument("--db-url", default=None, help="Libpq connection string. Overrides DATABASE_URL.")
    p.add_argument("--db-role", default=None, help="Optional database role to SET after connect (e.g. postgres).")
    p.add_argument("--confirm-live", action="store_true", help="Required affirmative flag for any DB connection.")
    p.add_argument("--manifest-path", default=None)
    p.add_argument("--output-root", default=None)
    p.add_argument("--run-timestamp", type=_run_timestamp_type, default=None,
                   help="ISO 8601 UTC compact (YYYYMMDDTHHMMSSZ). Default: now UTC.")
    p.add_argument("--dry-run", action="store_true",
                   help="Validate + plan + report; no disk writes.")
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
    preservation = manifest.get("preservation", [])
    if not isinstance(preservation, list):
        _refuse(20, "Manifest 'preservation' is not a list.")

    run_timestamp = args.run_timestamp or _utc_now_compact()
    run_dir = output_root / run_timestamp
    out_subdir = run_dir / "preservation"
    index_path = run_dir / "preservation_index.json"

    conn = _connect_session(db_url, args.db_role)
    host, db = _conn_target(conn)

    mode = "dry-run" if args.dry_run else "real-run"
    _log(SCRIPT_NAME, f"mode={mode} target host={host} db={db}")
    _log("manifest", f"path={manifest_path} schema_version={manifest['schema_version']} preservation_entries={len(preservation)}")

    if not args.dry_run and (out_subdir.exists() or index_path.exists()):
        conn.close()
        _refuse(60, f"Preservation output already exists under {run_dir}; choose a new --run-timestamp.")

    plans: list[tuple[str, str, int, str]] = []
    for i, entry in enumerate(preservation):
        kind, sel = _classify_preservation_entry(entry)
        if kind == "malformed":
            conn.close()
            _refuse(22, f"Preservation entry index {i} missing required keys: ['table'].")
        if kind == "other":
            conn.close()
            _refuse(40, f"Preservation entry '{sel}' is neither concrete table nor auth.* directive. Classify explicitly in manifest.")
        if kind == "auth":
            _log("plan", f"{sel} preserved by non-action, not exportable by this script")
            continue
        schema, table = sel.split(".", 1)
        n = _row_count(conn, schema, table)
        rel_file = f"preservation/{schema}__{table}.json"
        plans.append((schema, table, n, rel_file))
        _log("plan", f"{sel} rows={n} file={rel_file}")

    total_rows = sum(p[2] for p in plans)
    _log("summary", f"planned_tables={len(plans)} planned_rows={total_rows} output_run={run_timestamp} dry_run={str(args.dry_run).lower()}")

    if args.dry_run:
        _log("exit", "dry-run complete; no directories or JSON files written")
        conn.close()
        sys.exit(0)

    # Real run
    try:
        out_subdir.mkdir(parents=True, exist_ok=False)
    except FileExistsError:
        conn.close()
        _refuse(60, f"Preservation output already exists under {run_dir}; choose a new --run-timestamp.")
    except OSError as e:
        conn.close()
        _refuse(61, f"mkdir failed for {out_subdir}: {e}.")

    files = []
    for schema, table, _n_planned, rel_file in plans:
        pk_cols = _primary_key_columns(conn, schema, table)
        out_path = run_dir / rel_file
        n_written = _export_table(conn, schema, table, pk_cols, out_path)
        files.append({"table": f"{schema}.{table}", "path": rel_file, "row_count": n_written})
        _log("write", f"{schema}.{table} rows={n_written} -> {rel_file}")

    index = {
        "export_version": EXPORT_VERSION,
        "script": SCRIPT_NAME,
        "manifest_schema_version": SUPPORTED_MANIFEST_VERSION,
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "source": {"host": host, "database": db},
        "run_timestamp": run_timestamp,
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

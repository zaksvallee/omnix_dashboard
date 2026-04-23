#!/usr/bin/env python3
"""
Read-only readiness check for Layer 2 post-cutover 4b constraints.

Run after the wipe and preservation row-count verification, before applying
supabase/manual/post_cutover_constraints/*.sql. It reports the live rows that
would cause the staged constraint files to fail.
"""

from __future__ import annotations

import argparse
import os
import sys

import psycopg
from psycopg import sql as psql


SCRIPT_NAME = "cutover_4b_readiness_check"


def _log(tag: str, message: str) -> None:
    print(f"[{tag}] {message}", flush=True)


def _refuse(code: int, message: str) -> "NoReturn":
    print(f"[refuse] code={code} {message}", file=sys.stderr, flush=True)
    sys.exit(code)


def _connect(db_url: str, db_role: str | None) -> psycopg.Connection:
    try:
        conn = psycopg.connect(db_url, autocommit=True, application_name=SCRIPT_NAME)
    except psycopg.Error as exc:
        _refuse(30, f"Connection failed: {exc}")
    try:
        with conn.cursor() as cur:
            cur.execute("SET statement_timeout = '60s';")
            cur.execute("SET lock_timeout = '5s';")
            if db_role:
                cur.execute(psql.SQL("SET ROLE {}").format(psql.Identifier(db_role)))
    except psycopg.Error as exc:
        conn.close()
        _refuse(30, f"Session setup failed: {exc}")
    return conn


def _conn_target(conn: psycopg.Connection) -> tuple[str, str]:
    info = conn.info
    return (info.host or "<unknown-host>", info.dbname or "<unknown-db>")


def _scalar(cur: psycopg.Cursor, query: str) -> int:
    cur.execute(query)
    return int(cur.fetchone()[0])


def _duplicate_rows(cur: psycopg.Cursor, table: str, column: str) -> list[tuple[object, int]]:
    cur.execute(
        psql.SQL(
            """
            SELECT {column}, count(*)::bigint
            FROM {table}
            WHERE {column} IS NOT NULL
            GROUP BY {column}
            HAVING count(*) > 1
            ORDER BY count(*) DESC, {column}
            LIMIT 20
            """
        ).format(
            table=psql.SQL(table),
            column=psql.Identifier(column),
        )
    )
    return [(row[0], int(row[1])) for row in cur.fetchall()]


def _staged_constraints_present(cur: psycopg.Cursor) -> list[str]:
    names = [
        "client_evidence_ledger_client_id_fkey",
        "client_conversation_messages_client_id_fkey",
        "client_conversation_acknowledgements_client_id_fkey",
        "client_conversation_push_queue_client_id_fkey",
        "client_conversation_push_sync_state_client_id_fkey",
        "guard_ops_events_guard_id_fkey",
        "incidents_site_id_fkey",
        "onyx_evidence_certificates_incident_id_fkey",
        "incident_aar_scores_incident_id_fkey",
        "incidents_status_check",
        "incidents_priority_check",
        "incidents_risk_level_check",
        "guards_grade_check",
        "guards_full_name_unique",
        "guards_guard_id_unique",
        "onyx_evidence_certificates_event_id_unique",
    ]
    cur.execute(
        """
        SELECT conname
        FROM pg_constraint c
        JOIN pg_namespace n ON n.oid = c.connamespace
        WHERE n.nspname = 'public'
          AND conname = ANY(%s)
        ORDER BY conname
        """,
        (names,),
    )
    return [row[0] for row in cur.fetchall()]


FK_TYPE_CHECKS: list[tuple[str, str, str]] = [
    (
        "client_evidence_ledger.client_id -> clients.client_id",
        "public.client_evidence_ledger.client_id",
        "public.clients.client_id",
    ),
    (
        "client_conversation_messages.client_id -> clients.client_id",
        "public.client_conversation_messages.client_id",
        "public.clients.client_id",
    ),
    (
        "client_conversation_acknowledgements.client_id -> clients.client_id",
        "public.client_conversation_acknowledgements.client_id",
        "public.clients.client_id",
    ),
    (
        "client_conversation_push_queue.client_id -> clients.client_id",
        "public.client_conversation_push_queue.client_id",
        "public.clients.client_id",
    ),
    (
        "client_conversation_push_sync_state.client_id -> clients.client_id",
        "public.client_conversation_push_sync_state.client_id",
        "public.clients.client_id",
    ),
    (
        "guard_ops_events.guard_id -> guards.guard_id",
        "public.guard_ops_events.guard_id",
        "public.guards.guard_id",
    ),
    ("incidents.site_id -> sites.site_id", "public.incidents.site_id", "public.sites.site_id"),
    (
        "onyx_evidence_certificates.incident_id -> incidents.id",
        "public.onyx_evidence_certificates.incident_id",
        "public.incidents.id",
    ),
    (
        "incident_aar_scores.incident_id -> incidents.id",
        "public.incident_aar_scores.incident_id",
        "public.incidents.id",
    ),
]


DEFERRED_FKS: list[tuple[str, str]] = [
    (
        "client_evidence_ledger.dispatch_id -> dispatch_intents.dispatch_id",
        "deferred: child column is text, parent column is uuid; requires schema redesign",
    ),
]


CHECKS: list[tuple[str, str]] = [
    (
        "fk client_evidence_ledger.client_id -> clients.client_id",
        """
        SELECT count(*)
        FROM public.client_evidence_ledger child
        WHERE child.client_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.clients parent
            WHERE parent.client_id::text = child.client_id::text
          )
        """,
    ),
    (
        "fk client_conversation_messages.client_id -> clients.client_id",
        """
        SELECT count(*)
        FROM public.client_conversation_messages child
        WHERE child.client_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.clients parent
            WHERE parent.client_id::text = child.client_id::text
          )
        """,
    ),
    (
        "fk client_conversation_acknowledgements.client_id -> clients.client_id",
        """
        SELECT count(*)
        FROM public.client_conversation_acknowledgements child
        WHERE child.client_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.clients parent
            WHERE parent.client_id::text = child.client_id::text
          )
        """,
    ),
    (
        "fk client_conversation_push_queue.client_id -> clients.client_id",
        """
        SELECT count(*)
        FROM public.client_conversation_push_queue child
        WHERE child.client_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.clients parent
            WHERE parent.client_id::text = child.client_id::text
          )
        """,
    ),
    (
        "fk client_conversation_push_sync_state.client_id -> clients.client_id",
        """
        SELECT count(*)
        FROM public.client_conversation_push_sync_state child
        WHERE child.client_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.clients parent
            WHERE parent.client_id::text = child.client_id::text
          )
        """,
    ),
    (
        "fk guard_ops_events.guard_id -> guards.guard_id",
        """
        SELECT count(*)
        FROM public.guard_ops_events child
        WHERE child.guard_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.guards parent
            WHERE parent.guard_id::text = child.guard_id::text
          )
        """,
    ),
    (
        "fk incidents.site_id -> sites.site_id",
        """
        SELECT count(*)
        FROM public.incidents child
        WHERE child.site_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.sites parent
            WHERE parent.site_id::text = child.site_id::text
          )
        """,
    ),
    (
        "fk onyx_evidence_certificates.incident_id -> incidents.id",
        """
        SELECT count(*)
        FROM public.onyx_evidence_certificates child
        WHERE child.incident_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.incidents parent
            WHERE parent.id::text = child.incident_id::text
          )
        """,
    ),
    (
        "fk incident_aar_scores.incident_id -> incidents.id",
        """
        SELECT count(*)
        FROM public.incident_aar_scores child
        WHERE child.incident_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.incidents parent
            WHERE parent.id::text = child.incident_id::text
          )
        """,
    ),
    ("not null incidents.site_id", "SELECT count(*) FROM public.incidents WHERE site_id IS NULL"),
    (
        "not null onyx_evidence_certificates.incident_id",
        "SELECT count(*) FROM public.onyx_evidence_certificates WHERE incident_id IS NULL",
    ),
    ("not null guards.full_name", "SELECT count(*) FROM public.guards WHERE full_name IS NULL"),
    ("not null guards.client_id", "SELECT count(*) FROM public.guards WHERE client_id IS NULL"),
    ("not null guards.primary_site_id", "SELECT count(*) FROM public.guards WHERE primary_site_id IS NULL"),
    (
        "not null client_evidence_ledger.previous_hash",
        "SELECT count(*) FROM public.client_evidence_ledger WHERE previous_hash IS NULL",
    ),
    (
        "check incidents.status canonical",
        """
        SELECT count(*)
        FROM public.incidents
        WHERE status IS NOT NULL
          AND status NOT IN ('detected', 'open', 'acknowledged', 'dispatched', 'on_site', 'secured', 'closed', 'false_alarm')
        """,
    ),
    (
        "check incidents.priority canonical",
        """
        SELECT count(*)
        FROM public.incidents
        WHERE priority IS NOT NULL
          AND priority NOT IN ('critical', 'high', 'medium', 'low')
        """,
    ),
    (
        "check incidents.risk_level canonical",
        """
        SELECT count(*)
        FROM public.incidents
        WHERE risk_level IS NOT NULL
          AND risk_level NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')
        """,
    ),
    (
        "check guards.grade canonical",
        """
        SELECT count(*)
        FROM public.guards
        WHERE grade IS NOT NULL
          AND grade NOT IN ('Grade A', 'Grade B', 'Grade C')
        """,
    ),
]

DUPLICATE_CHECKS = [
    ("unique guards.full_name", "public.guards", "full_name"),
    ("unique guards.guard_id", "public.guards", "guard_id"),
    ("unique onyx_evidence_certificates.event_id", "public.onyx_evidence_certificates", "event_id"),
]


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog=SCRIPT_NAME,
        description="Read-only readiness check for staged 4b constraints.",
    )
    parser.add_argument("--db-url", default=None, help="Libpq connection string. Overrides DATABASE_URL.")
    parser.add_argument("--db-role", default=None, help="Optional database role to SET after connect (e.g. postgres).")
    parser.add_argument("--confirm-live", action="store_true", help="Required affirmative flag for any DB connection.")
    return parser


def _column_type(cur: psycopg.Cursor, schema: str, table: str, column: str) -> str | None:
    cur.execute(
        """
        SELECT a.atttypid::regtype::text
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = %s
          AND c.relname = %s
          AND a.attname = %s
          AND a.attnum > 0
          AND NOT a.attisdropped
        """,
        (schema, table, column),
    )
    row = cur.fetchone()
    return str(row[0]) if row else None


def _split_qualified_column(name: str) -> tuple[str, str, str]:
    schema, table, column = name.split(".", 2)
    return schema, table, column


def main() -> None:
    args = _build_parser().parse_args()
    db_url = args.db_url or os.environ.get("DATABASE_URL", "")
    if not db_url:
        _refuse(10, "Provide DATABASE_URL env or --db-url flag.")
    if not args.confirm_live:
        _refuse(11, "Refusing to connect without --confirm-live.")

    conn = _connect(db_url, args.db_role)
    host, db = _conn_target(conn)
    blockers = 0
    _log(SCRIPT_NAME, f"target host={host} db={db} mode=read-only")

    try:
        with conn.cursor() as cur:
            cur.execute("BEGIN READ ONLY;")

            present_constraints = _staged_constraints_present(cur)
            if present_constraints:
                _log("ok", "staged constraints already present: " + ", ".join(present_constraints))
            else:
                _log("ok", "no staged constraints already present")

            for label, reason in DEFERRED_FKS:
                _log("deferred", f"fk {label}: {reason}")

            for label, child_ref, parent_ref in FK_TYPE_CHECKS:
                child_schema, child_table, child_column = _split_qualified_column(child_ref)
                parent_schema, parent_table, parent_column = _split_qualified_column(parent_ref)
                child_type = _column_type(cur, child_schema, child_table, child_column)
                parent_type = _column_type(cur, parent_schema, parent_table, parent_column)
                if child_type is None or parent_type is None:
                    blockers += 1
                    _log("blocker", f"fk {label}: missing column child={child_type} parent={parent_type}")
                elif child_type != parent_type:
                    blockers += 1
                    _log("blocker", f"fk {label}: type mismatch child={child_type} parent={parent_type}")
                else:
                    _log("ok", f"fk {label} type={child_type}")

            for label, query in CHECKS:
                count = _scalar(cur, query)
                if count:
                    blockers += 1
                    _log("blocker", f"{label}: rows={count}")
                else:
                    _log("ok", label)

            for label, table, column in DUPLICATE_CHECKS:
                dupes = _duplicate_rows(cur, table, column)
                if dupes:
                    blockers += 1
                    sample = "; ".join(f"{value!r} x {count}" for value, count in dupes)
                    _log("blocker", f"{label}: duplicate_groups={len(dupes)} sample={sample}")
                else:
                    _log("ok", label)

            cur.execute("ROLLBACK;")
    except psycopg.Error as exc:
        try:
            conn.rollback()
        except psycopg.Error:
            pass
        conn.close()
        _refuse(31, f"Read-only readiness query failed: {exc}")

    conn.close()
    if blockers:
        _log("summary", f"4b readiness failed blockers={blockers}")
        sys.exit(1)
    _log("summary", "4b readiness passed; staged constraints should apply")


if __name__ == "__main__":
    main()

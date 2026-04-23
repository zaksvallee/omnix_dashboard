#!/usr/bin/env python3
"""
Generate reviewed Layer 2 wipe SQL from supabase/manual/cutover/manifest.yaml.

This tool does not connect to the database and does not execute SQL. It writes
the destructive SQL artifact that an operator reviews before the runbook's wipe
gate. Execution remains manual and operator-confirmed.
"""

from __future__ import annotations

import argparse
import difflib
import sys
from pathlib import Path
from typing import Any

import yaml


SCRIPT_NAME = "cutover_generate_wipe_sql"
SUPPORTED_MANIFEST_VERSION = 1
DEFAULT_MANIFEST_REL = Path("supabase/manual/cutover/manifest.yaml")
DEFAULT_OUTPUT_REL = Path("supabase/manual/cutover/wipe.sql")


def _find_repo_root(start: Path) -> Path | None:
    p = start.resolve()
    while True:
        if (p / ".git").exists():
            return p
        if p == p.parent:
            return None
        p = p.parent


def _display_path(path: Path) -> str:
    repo_root = _find_repo_root(path)
    if repo_root:
        try:
            return str(path.resolve().relative_to(repo_root))
        except ValueError:
            pass
    return str(path)


def _refuse(message: str) -> None:
    print(f"[{SCRIPT_NAME}] refuse: {message}", file=sys.stderr)
    raise SystemExit(2)


def _load_manifest(path: Path) -> dict[str, Any]:
    if not path.exists():
        _refuse(f"manifest not found: {path}")
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        _refuse(f"manifest YAML parse failed: {exc}")
    if not isinstance(data, dict):
        _refuse("manifest top-level must be a mapping")
    if data.get("schema_version") != SUPPORTED_MANIFEST_VERSION:
        _refuse(
            f"unsupported schema_version={data.get('schema_version')!r}; "
            f"expected {SUPPORTED_MANIFEST_VERSION}"
        )
    return data


def _table_entries(manifest: dict[str, Any], key: str) -> list[str]:
    raw = manifest.get(key)
    if not isinstance(raw, list):
        _refuse(f"manifest {key!r} must be a list")
    out: list[str] = []
    for i, entry in enumerate(raw):
        if not isinstance(entry, dict) or "table" not in entry:
            _refuse(f"{key}[{i}] missing table")
        table = str(entry["table"]).strip()
        if key != "preservation" and "*" in table:
            _refuse(f"{key}[{i}] is not a concrete table: {table}")
        out.append(table)
    return out


def _wipe_entries(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    raw = manifest.get("wipe")
    if not isinstance(raw, list):
        _refuse("manifest 'wipe' must be a list")
    out: list[dict[str, Any]] = []
    for i, entry in enumerate(raw):
        if not isinstance(entry, dict) or "table" not in entry:
            _refuse(f"wipe[{i}] missing table")
        table = str(entry["table"]).strip()
        deps = entry.get("fk_dependencies", [])
        if not isinstance(deps, list):
            _refuse(f"{table} fk_dependencies must be a list")
        out.append({"table": table, "fk_dependencies": [str(dep).strip() for dep in deps]})
    return out


def _split_fqn(table: str) -> tuple[str, str]:
    parts = table.split(".")
    if len(parts) != 2 or not all(parts):
        _refuse(f"table is not schema-qualified: {table}")
    return parts[0], parts[1]


def _split_column_fqn(column: str) -> tuple[str, str, str]:
    parts = column.split(".")
    if len(parts) != 3 or not all(parts):
        _refuse(f"column is not schema.table.column qualified: {column}")
    return parts[0], parts[1], parts[2]


def _quote_ident(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def _quote_table(table: str) -> str:
    schema, name = _split_fqn(table)
    return f"{_quote_ident(schema)}.{_quote_ident(name)}"


def _sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _regclass_text(table: str) -> str:
    return _quote_table(table)


def _values_rows(rows: list[tuple[str, ...]], *, indent: str = "        ") -> str:
    rendered = []
    for row in rows:
        rendered.append(indent + "(" + ", ".join(_sql_literal(value) for value in row) + ")")
    return ",\n".join(rendered)


def _validate_sets(
    preservation: list[str],
    wipe: list[str],
    untouched: list[str],
) -> None:
    preservation_tables = {table for table in preservation if table != "auth.*"}
    wipe_tables = set(wipe)
    untouched_tables = set(untouched)
    overlaps = {
        "preservation/wipe": preservation_tables & wipe_tables,
        "preservation/untouched": preservation_tables & untouched_tables,
        "wipe/untouched": wipe_tables & untouched_tables,
    }
    for label, tables in overlaps.items():
        if tables:
            _refuse(f"table set overlap {label}: {sorted(tables)}")
    if len(wipe) != len(wipe_tables):
        _refuse("wipe list contains duplicate tables")


def _knock_on_specs(manifest: dict[str, Any], wipe_tables: set[str]) -> list[dict[str, str]]:
    specs = []
    raw = manifest.get("knock_on_fks", [])
    if not isinstance(raw, list):
        _refuse("manifest 'knock_on_fks' must be a list when present")
    for i, entry in enumerate(raw):
        if not isinstance(entry, dict):
            _refuse(f"knock_on_fks[{i}] must be a mapping")
        parent = str(entry.get("parent_preservation_table", "")).strip()
        child = str(entry.get("child_wipe_table", "")).strip()
        column = str(entry.get("column", "")).strip()
        if not parent or not child or not column:
            _refuse(f"knock_on_fks[{i}] missing parent_preservation_table, child_wipe_table, or column")
        if child not in wipe_tables:
            _refuse(f"knock_on_fks[{i}] child_wipe_table is not in wipe set: {child}")
        col_schema, col_table, _col = _split_column_fqn(column)
        parent_schema, parent_table = _split_fqn(parent)
        if (col_schema, col_table) != (parent_schema, parent_table):
            _refuse(f"knock_on_fks[{i}] column does not belong to parent table: {column}")
        specs.append({"parent": parent, "child": child, "column": column})
    return specs


def _external_empty_specs(
    manifest: dict[str, Any],
    wipe_tables: set[str],
    untouched_tables: set[str],
) -> list[dict[str, str]]:
    specs = []
    raw = manifest.get("external_empty_untouched_fks", [])
    if not isinstance(raw, list):
        _refuse("manifest 'external_empty_untouched_fks' must be a list when present")
    for i, entry in enumerate(raw):
        if not isinstance(entry, dict):
            _refuse(f"external_empty_untouched_fks[{i}] must be a mapping")
        source = str(entry.get("source_untouched_table", "")).strip()
        target = str(entry.get("target_wipe_table", "")).strip()
        column = str(entry.get("column", "")).strip()
        if not source or not target or not column:
            _refuse(
                f"external_empty_untouched_fks[{i}] missing source_untouched_table, "
                "target_wipe_table, or column"
            )
        if source not in untouched_tables:
            _refuse(f"external_empty_untouched_fks[{i}] source is not in untouched set: {source}")
        if target not in wipe_tables:
            _refuse(f"external_empty_untouched_fks[{i}] target is not in wipe set: {target}")
        col_schema, col_table, _col = _split_column_fqn(column)
        source_schema, source_table = _split_fqn(source)
        if (col_schema, col_table) != (source_schema, source_table):
            _refuse(f"external_empty_untouched_fks[{i}] column does not belong to source: {column}")
        specs.append({"source": source, "target": target, "column": column})
    return specs


def _delete_closure(
    *,
    initial_delete_tables: set[str],
    dependency_map: dict[str, list[str]],
) -> set[str]:
    delete_tables = set(initial_delete_tables)
    changed = True
    while changed:
        changed = False
        for table in list(delete_tables):
            for dep in dependency_map.get(table, []):
                if dep not in delete_tables:
                    delete_tables.add(dep)
                    changed = True
    return delete_tables


def _render_preflight_do(
    *,
    wipe_tables: list[str],
    truncate_tables: list[str],
    delete_tables: list[str],
    knock_on_specs: list[dict[str, str]],
    external_empty_specs: list[dict[str, str]],
) -> str:
    wipe_rows = [(table, _regclass_text(table)) for table in wipe_tables]
    truncate_rows = [(table, _regclass_text(table)) for table in truncate_tables]
    delete_rows = [(table, _regclass_text(table)) for table in delete_tables]
    expected_rows = [
        (
            spec["parent"],
            _regclass_text(spec["parent"]),
            spec["child"],
            _regclass_text(spec["child"]),
            "n",
        )
        for spec in knock_on_specs
    ] + [
        (
            spec["source"],
            _regclass_text(spec["source"]),
            spec["target"],
            _regclass_text(spec["target"]),
            "",
        )
        for spec in external_empty_specs
    ]
    expected_cte_body = (
        "        VALUES\n" + _values_rows(expected_rows)
        if expected_rows
        else "        SELECT NULL::text, NULL::text, NULL::text, NULL::text, NULL::text WHERE false"
    )
    empty_rows = sorted(
        {
            (spec["source"], _regclass_text(spec["source"]), spec["column"])
            for spec in external_empty_specs
        }
    )
    empty_cte_body = (
        "        VALUES\n" + _values_rows(empty_rows)
        if empty_rows
        else "        SELECT NULL::text, NULL::text, NULL::text WHERE false"
    )

    return f"""DO $wipe_preflight$
DECLARE
    missing text;
    unexpected text;
    empty_ref record;
    empty_count bigint;
BEGIN
    WITH wipe(label, regclass_name) AS (
        VALUES
{_values_rows(wipe_rows)}
    )
    SELECT string_agg(label, ', ' ORDER BY label)
    INTO missing
    FROM wipe
    WHERE to_regclass(regclass_name) IS NULL;

    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Wipe preflight failed; missing wipe tables: %', missing;
    END IF;

    WITH truncate_tables(label, regclass_name) AS (
        VALUES
{_values_rows(truncate_rows)}
    )
    SELECT string_agg(format('%s -> %s (%s)', c.conrelid::regclass, c.confrelid::regclass, c.conname), E'\\n')
    INTO unexpected
    FROM pg_constraint c
    JOIN truncate_tables target ON c.confrelid = to_regclass(target.regclass_name)
    WHERE c.contype = 'f'
      AND NOT EXISTS (
          SELECT 1
          FROM truncate_tables source
          WHERE c.conrelid = to_regclass(source.regclass_name)
      );

    IF unexpected IS NOT NULL THEN
        RAISE EXCEPTION 'Unsafe TRUNCATE target: external FK(s) reference truncate tables:%', E'\\n' || unexpected;
    END IF;

    WITH delete_tables(label, regclass_name) AS (
        VALUES
{_values_rows(delete_rows)}
    ),
    wipe(label, regclass_name) AS (
        VALUES
{_values_rows(wipe_rows)}
    ),
    expected_external(source_label, source_regclass_name, target_label, target_regclass_name, required_confdeltype) AS (
{expected_cte_body}
    )
    SELECT string_agg(format('%s -> %s (%s)', c.conrelid::regclass, c.confrelid::regclass, c.conname), E'\\n')
    INTO unexpected
    FROM pg_constraint c
    JOIN delete_tables target ON c.confrelid = to_regclass(target.regclass_name)
    WHERE c.contype = 'f'
      AND NOT EXISTS (
          SELECT 1
          FROM wipe source
          WHERE c.conrelid = to_regclass(source.regclass_name)
      )
      AND NOT EXISTS (
          SELECT 1
          FROM expected_external expected
          WHERE c.conrelid = to_regclass(expected.source_regclass_name)
            AND c.confrelid = to_regclass(expected.target_regclass_name)
      );

    IF unexpected IS NOT NULL THEN
        RAISE EXCEPTION 'Unsafe DELETE target: unexpected external FK(s) reference delete tables:%', E'\\n' || unexpected;
    END IF;

    WITH expected_external(source_label, source_regclass_name, target_label, target_regclass_name, required_confdeltype) AS (
{expected_cte_body}
    )
    SELECT string_agg(
        CASE
            WHEN c.oid IS NULL THEN
                format('%s -> %s (missing expected FK)', expected.source_label, expected.target_label)
            ELSE
                format('%s -> %s (%s) delete_action=%s', c.conrelid::regclass, c.confrelid::regclass, c.conname, c.confdeltype)
        END,
        E'\\n'
    )
    INTO unexpected
    FROM expected_external expected
    LEFT JOIN pg_constraint c
      ON c.conrelid = to_regclass(expected.source_regclass_name)
     AND c.confrelid = to_regclass(expected.target_regclass_name)
     AND c.contype = 'f'
    WHERE c.oid IS NULL
       OR (expected.required_confdeltype <> '' AND c.confdeltype <> expected.required_confdeltype);

    IF unexpected IS NOT NULL THEN
        RAISE EXCEPTION 'Expected external FK missing or delete action mismatch:%', E'\\n' || unexpected;
    END IF;

    FOR empty_ref IN
        WITH expected_empty(source_label, source_regclass_name, column_label) AS (
{empty_cte_body}
        )
        SELECT source_label, source_regclass_name, column_label
        FROM expected_empty
    LOOP
        EXECUTE format('SELECT count(*) FROM %s', empty_ref.source_regclass_name) INTO empty_count;
        IF empty_count <> 0 THEN
            RAISE EXCEPTION
                'Untouched table % must be empty before deleting wipe parent via %; found % row(s)',
                empty_ref.source_label,
                empty_ref.column_label,
                empty_count;
        END IF;
    END LOOP;
END
$wipe_preflight$;
"""


def _render_sql(manifest_path: Path, manifest: dict[str, Any]) -> str:
    preservation = _table_entries(manifest, "preservation")
    wipe_entries = _wipe_entries(manifest)
    wipe_tables = [entry["table"] for entry in wipe_entries]
    untouched = _table_entries(manifest, "untouched")
    _validate_sets(preservation, wipe_tables, untouched)

    wipe_set = set(wipe_tables)
    dependency_map = {entry["table"]: entry["fk_dependencies"] for entry in wipe_entries}
    for entry in wipe_entries:
        for dep in entry["fk_dependencies"]:
            if dep not in wipe_set:
                _refuse(f"{entry['table']} fk_dependency not in wipe set: {dep}")

    knock_on_specs = _knock_on_specs(manifest, wipe_set)
    external_empty_specs = _external_empty_specs(manifest, wipe_set, set(untouched))
    initial_delete_tables = (
        {spec["child"] for spec in knock_on_specs}
        | {spec["target"] for spec in external_empty_specs}
    )
    delete_set = _delete_closure(
        initial_delete_tables=initial_delete_tables,
        dependency_map=dependency_map,
    )
    delete_tables = [table for table in wipe_tables if table in delete_set]
    truncate_tables = [table for table in wipe_tables if table not in delete_set]

    lines: list[str] = [
        "-- Layer 2 cutover wipe SQL for MS Vallee test-site reset.",
        f"-- Generated by scripts/{Path(__file__).name}.",
        f"-- Source manifest: {_display_path(manifest_path)}",
        "-- Do not edit by hand; regenerate from manifest and review before execution.",
        "--",
        "-- This file is destructive. It is only executed at RUNBOOK.md step 5,",
        "-- after QA and preservation exports have completed and the operator has",
        "-- confirmed: PROCEED LAYER 2 WIPE FOR MS VALLEE TEST SITE",
        "",
        "\\set ON_ERROR_STOP on",
        "",
        "BEGIN;",
        "SET LOCAL lock_timeout = '5s';",
        "SET LOCAL statement_timeout = '10min';",
        "SET LOCAL application_name = 'onyx_layer2_cutover_wipe';",
        "",
        "-- Preflight: refuse if the live FK shape does not match the reviewed manifest assumptions.",
        _render_preflight_do(
            wipe_tables=wipe_tables,
            truncate_tables=truncate_tables,
            delete_tables=delete_tables,
            knock_on_specs=knock_on_specs,
            external_empty_specs=external_empty_specs,
        ).rstrip(),
        "",
    ]

    for spec in knock_on_specs:
        col_schema, col_table, col_name = _split_column_fqn(spec["column"])
        parent_table = f"{col_schema}.{col_table}"
        lines.extend(
            [
                f"-- Preserve {spec['parent']} while wiping {spec['child']}: null the FK column first.",
                "WITH updated AS (",
                f"    UPDATE {_quote_table(parent_table)}",
                f"    SET {_quote_ident(col_name)} = NULL",
                f"    WHERE {_quote_ident(col_name)} IS NOT NULL",
                "    RETURNING 1",
                ")",
                f"SELECT {_sql_literal(spec['column'] + ' nulled')} AS action, count(*) AS rows FROM updated;",
                "",
            ]
        )

    lines.extend(
        [
            f"-- Truncate {len(truncate_tables)} wipe tables. No CASCADE: external FK preflight above must pass first.",
            "TRUNCATE TABLE",
        ]
    )
    for i, table in enumerate(truncate_tables):
        suffix = "," if i < len(truncate_tables) - 1 else ""
        lines.append(f"    {_quote_table(table)}{suffix}")
    lines.extend(["RESTART IDENTITY;", ""])

    for table in delete_tables:
        lines.extend(
            [
                f"-- Delete {table} instead of truncating because non-wipe tables reference it directly or through delete-closure.",
                "WITH deleted AS (",
                f"    DELETE FROM {_quote_table(table)}",
                "    RETURNING 1",
                ")",
                f"SELECT {_sql_literal(table + ' deleted')} AS action, count(*) AS rows FROM deleted;",
                "",
            ]
        )

    lines.extend(["COMMIT;", ""])
    return "\n".join(lines)


def _build_parser() -> argparse.ArgumentParser:
    repo_root = _find_repo_root(Path(__file__))
    default_manifest = repo_root / DEFAULT_MANIFEST_REL if repo_root else DEFAULT_MANIFEST_REL
    default_output = repo_root / DEFAULT_OUTPUT_REL if repo_root else DEFAULT_OUTPUT_REL
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest-path", default=str(default_manifest))
    parser.add_argument("--output", default=str(default_output))
    parser.add_argument("--check", action="store_true", help="Refuse if --output differs from generated SQL.")
    parser.add_argument("--stdout", action="store_true", help="Print generated SQL instead of writing --output.")
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    manifest_path = Path(args.manifest_path)
    output_path = Path(args.output)
    manifest = _load_manifest(manifest_path)
    rendered = _render_sql(manifest_path, manifest)

    if args.stdout:
        print(rendered, end="")
        return 0

    if args.check:
        if not output_path.exists():
            _refuse(f"output does not exist: {output_path}")
        current = output_path.read_text(encoding="utf-8")
        if current != rendered:
            diff = "\n".join(
                difflib.unified_diff(
                    current.splitlines(),
                    rendered.splitlines(),
                    fromfile=str(output_path),
                    tofile="generated",
                    lineterm="",
                )
            )
            print(diff, file=sys.stderr)
            _refuse("output is stale; regenerate wipe SQL")
        print(f"[{SCRIPT_NAME}] ok: {output_path} matches manifest")
        return 0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")
    print(f"[{SCRIPT_NAME}] wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

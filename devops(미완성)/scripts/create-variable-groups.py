#!/usr/bin/env python3
"""Create or update Azure DevOps Variable Groups from template YAML files.

Template format: key: value (single line per key). This script supports simple YAML maps.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List


def run(cmd: List[str], check: bool = True) -> subprocess.CompletedProcess:
    result = subprocess.run(cmd, text=True, capture_output=True)
    if check and result.returncode != 0:
        raise RuntimeError(
            f"Command failed ({result.returncode}): {' '.join(cmd)}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )
    return result


def parse_template(path: Path) -> Dict[str, str]:
    data: Dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        data[key] = value
    return data


def get_group_id(group_name: str) -> str | None:
    cmd = [
        "az",
        "pipelines",
        "variable-group",
        "list",
        "--query",
        f"[?name=='{group_name}'].id | [0]",
        "-o",
        "tsv",
    ]
    result = run(cmd, check=False)
    group_id = result.stdout.strip()
    return group_id if group_id else None


def upsert_variable(group_id: str, key: str, value: str, secret: bool) -> None:
    exists_cmd = [
        "az",
        "pipelines",
        "variable-group",
        "variable",
        "list",
        "--group-id",
        group_id,
        "--query",
        f"contains(keys(@), '{key}')",
        "-o",
        "tsv",
    ]
    exists = run(exists_cmd, check=False).stdout.strip().lower() == "true"

    if exists:
        cmd = [
            "az",
            "pipelines",
            "variable-group",
            "variable",
            "update",
            "--group-id",
            group_id,
            "--name",
            key,
        ]
    else:
        cmd = [
            "az",
            "pipelines",
            "variable-group",
            "variable",
            "create",
            "--group-id",
            group_id,
            "--name",
            key,
        ]

    if secret:
        cmd.extend(["--secret", "true", "--value", value])
    else:
        cmd.extend(["--value", value])

    run(cmd)


def normalize_secret_keys(secret_keys_raw: str) -> List[str]:
    if not secret_keys_raw:
        return []
    return [k.strip() for k in secret_keys_raw.split(",") if k.strip()]


def load_secret_value(key: str) -> str:
    env_key = f"VG_SECRET_{re.sub(r'[^A-Za-z0-9]', '_', key).upper()}"
    value = os.getenv(env_key)
    if not value:
        raise RuntimeError(
            f"Missing secret value for {key}. Set environment variable {env_key}."
        )
    return value


def ensure_group(group_name: str, authorize: bool) -> str:
    group_id = get_group_id(group_name)
    if group_id:
        return group_id

    cmd = [
        "az",
        "pipelines",
        "variable-group",
        "create",
        "--name",
        group_name,
        "--authorize",
        "true" if authorize else "false",
        "--variables",
        "bootstrap_key=bootstrap_value",
        "--query",
        "id",
        "-o",
        "tsv",
    ]
    group_id = run(cmd).stdout.strip()

    run(
        [
            "az",
            "pipelines",
            "variable-group",
            "variable",
            "delete",
            "--group-id",
            group_id,
            "--name",
            "bootstrap_key",
            "--yes",
        ],
        check=False,
    )
    return group_id


def main() -> int:
    parser = argparse.ArgumentParser(description="Create/update Azure DevOps Variable Groups from templates")
    parser.add_argument("--org", required=True, help="Azure DevOps organization URL")
    parser.add_argument("--project", required=True, help="Azure DevOps project name")
    parser.add_argument("--dev-template", default="devops/variable-groups/dev.variable-group.template.yml")
    parser.add_argument("--prod-template", default="devops/variable-groups/prod.variable-group.template.yml")
    parser.add_argument("--dev-group-name", default="iwon-vm-dev-vg")
    parser.add_argument("--prod-group-name", default="iwon-vm-prod-vg")
    parser.add_argument(
        "--secret-keys",
        default="DB_APP_PASSWORD,DB_ROOT_PASSWORD,DB_ROLLBACK_NOTIFY_WEBHOOK_URL",
        help="Comma-separated keys to store as secrets",
    )
    parser.add_argument("--authorize", action="store_true", help="Authorize variable group for all pipelines")
    args = parser.parse_args()

    run(["az", "extension", "add", "--name", "azure-devops", "--only-show-errors"], check=False)
    run(["az", "devops", "configure", "--defaults", f"organization={args.org}", f"project={args.project}"])

    secret_keys = set(normalize_secret_keys(args.secret_keys))

    for template_path, group_name in [
        (Path(args.dev_template), args.dev_group_name),
        (Path(args.prod_template), args.prod_group_name),
    ]:
        if not template_path.exists():
            raise FileNotFoundError(f"Template not found: {template_path}")

        data = parse_template(template_path)
        group_id = ensure_group(group_name, authorize=args.authorize)

        for key, value in data.items():
            is_secret = key in secret_keys
            real_value = load_secret_value(key) if is_secret else value
            upsert_variable(group_id, key, real_value, secret=is_secret)

        print(f"Updated variable group: {group_name} (id={group_id})")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise

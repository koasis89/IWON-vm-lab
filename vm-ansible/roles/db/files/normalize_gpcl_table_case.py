#!/usr/bin/env python3
import argparse
import subprocess


def run_query(db_name: str, db_user: str, db_password: str, sql: str):
    cmd = [
        "mariadb",
        f"-u{db_user}",
        f"-p{db_password}",
        db_name,
        "-Nse",
        sql,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def exec_sql(db_name: str, db_user: str, db_password: str, sql: str):
    cmd = [
        "mariadb",
        f"-u{db_user}",
        f"-p{db_password}",
        db_name,
        "-e",
        sql,
    ]
    subprocess.run(cmd, check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db-name", required=True)
    parser.add_argument("--db-user", required=True)
    parser.add_argument("--db-password", required=True)
    args = parser.parse_args()

    table_mode = run_query(args.db_name, args.db_user, args.db_password, "SHOW VARIABLES LIKE 'lower_case_table_names'")
    print("LOWER_CASE_TABLE_NAMES=" + (table_mode[0].split()[1] if table_mode else "unknown"))

    lower_tables = run_query(args.db_name, args.db_user, args.db_password, "SHOW TABLES LIKE 'gpcl_%'")
    upper_tables = set(run_query(args.db_name, args.db_user, args.db_password, "SHOW TABLES LIKE 'GPCL_%'"))

    changed = False
    for table_name in lower_tables:
        upper_name = table_name.upper()
        if upper_name in upper_tables:
            print(f"SKIP {table_name} -> {upper_name} (already exists)")
            continue
        exec_sql(args.db_name, args.db_user, args.db_password, f"RENAME TABLE `{table_name}` TO `{upper_name}`")
        print(f"RENAMED {table_name} -> {upper_name}")
        changed = True

    print("RESULT=changed" if changed else "RESULT=unchanged")


if __name__ == "__main__":
    main()
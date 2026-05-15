#!/usr/bin/env python3
"""Generate Ansible inventory from Terraform output JSON."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def _value(data: dict, key: str):
    if key not in data:
        raise KeyError(f"Missing Terraform output key: {key}")
    return data[key]["value"]


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate inventory.ini from terraform output -json")
    parser.add_argument("--tf-output", required=True, help="Path to terraform output JSON file")
    parser.add_argument("--output", required=True, help="Path to generated inventory.ini")
    parser.add_argument("--ssh-user", default="iwon", help="Ansible SSH user")
    parser.add_argument("--ssh-key-path", default="~/.ssh/id_rsa", help="SSH key path used by Ansible")
    args = parser.parse_args()

    tf_output_path = Path(args.tf_output)
    output_path = Path(args.output)

    data = json.loads(tf_output_path.read_text(encoding="utf-8"))

    vm_private_ips = _value(data, "vm_private_ips")
    bastion_public_ip = _value(data, "bastion_public_ip")

    required_vms = {
        "web01": "web",
        "was01": "was",
        "app01": "app",
        "smartcontract01": "integration",
        "db01": "db",
        "kafka01": "kafka",
    }

    missing = [vm for vm in required_vms if vm not in vm_private_ips]
    if missing:
        raise KeyError(f"Missing VM IPs in Terraform output: {', '.join(missing)}")

    lines = []
    lines.append("[bastion]")
    lines.append(f"bastion01 ansible_host={bastion_public_ip}")
    lines.append("")

    for vm_name, group in required_vms.items():
        lines.append(f"[{group}]")
        host_alias = "smartcontract01" if vm_name == "smartcontract01" else vm_name
        lines.append(f"{host_alias} ansible_host={vm_private_ips[vm_name]}")
        lines.append("")

    lines.extend(
        [
            "[app_vms:children]",
            "was",
            "app",
            "integration",
            "",
            "[internal_vms:children]",
            "web",
            "was",
            "app",
            "integration",
            "db",
            "kafka",
            "",
            "[all:vars]",
            f"ansible_user={args.ssh_user}",
            f"ansible_ssh_private_key_file={args.ssh_key_path}",
            "ansible_python_interpreter=/usr/bin/python3",
            "",
            "[internal_vms:vars]",
            f"ansible_ssh_common_args='-o ProxyJump={args.ssh_user}@{bastion_public_ip}'",
            "",
        ]
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated inventory: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

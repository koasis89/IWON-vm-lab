#!/usr/bin/env python3
import argparse
import shutil
import struct
import sys
import tempfile
import zipfile
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--jar", required=True)
    parser.add_argument("--class", dest="class_path", required=True)
    parser.add_argument("--replace", action="append", default=[])
    return parser.parse_args()


def parse_replacements(raw_items):
    replacements = []
    for item in raw_items:
      if "=" not in item:
        raise ValueError(f"invalid replacement: {item}")
      old_value, new_value = item.split("=", 1)
      replacements.append((old_value, new_value))
    return replacements


def collect_utf8_entries(class_bytes):
    if class_bytes[:4] != b"\xca\xfe\xba\xbe":
        raise ValueError("not a valid class file")

    constant_pool_count = struct.unpack_from(">H", class_bytes, 8)[0]
    offset = 10
    index = 1
    entries = []

    while index < constant_pool_count:
        tag = class_bytes[offset]
        offset += 1

        if tag == 1:
            length_offset = offset
            length = struct.unpack_from(">H", class_bytes, offset)[0]
            offset += 2
            data_offset = offset
            data = class_bytes[data_offset:data_offset + length]
            entries.append({
                "index": index,
                "length_offset": length_offset,
                "data_offset": data_offset,
                "end_offset": data_offset + length,
                "value": data.decode("utf-8"),
            })
            offset += length
        elif tag in (3, 4, 9, 10, 11, 12, 17, 18):
            offset += 4
        elif tag in (5, 6):
            offset += 8
            index += 1
        elif tag in (7, 8, 16, 19, 20):
            offset += 2
        elif tag == 15:
            offset += 3
        else:
            raise ValueError(f"unsupported constant pool tag: {tag}")

        index += 1

    return entries


def patch_class_bytes(class_bytes, replacements):
    utf8_entries = collect_utf8_entries(class_bytes)
    mutable = bytearray(class_bytes)
    edits = []
    status = []

    for old_value, new_value in replacements:
        old_entry = next((entry for entry in utf8_entries if entry["value"] == old_value), None)
        if old_entry is not None:
            edits.append((old_entry["length_offset"], old_entry["end_offset"], new_value))
            status.append(f"UPDATED {old_value} -> {new_value}")
            continue

        new_entry = next((entry for entry in utf8_entries if entry["value"] == new_value), None)
        if new_entry is not None:
            status.append(f"ALREADY {new_value}")
            continue

        raise ValueError(f"neither source nor target constant found: {old_value} -> {new_value}")

    for length_offset, end_offset, new_value in sorted(edits, key=lambda item: item[0], reverse=True):
        encoded = new_value.encode("utf-8")
        mutable[length_offset:end_offset] = struct.pack(">H", len(encoded)) + encoded

    return bytes(mutable), status, bool(edits)


def rewrite_jar(jar_path, class_path, new_class_bytes):
    jar_path = Path(jar_path)
    backup_path = jar_path.with_suffix(jar_path.suffix + ".bak")
    if not backup_path.exists():
        shutil.copy2(jar_path, backup_path)

    fd, temp_path = tempfile.mkstemp(suffix=".jar", dir=str(jar_path.parent))
    Path(temp_path).unlink(missing_ok=True)

    try:
        with zipfile.ZipFile(jar_path, "r") as source, zipfile.ZipFile(temp_path, "w") as target:
            for info in source.infolist():
                data = new_class_bytes if info.filename == class_path else source.read(info.filename)
                target.writestr(info, data)
        shutil.move(temp_path, jar_path)
    finally:
        Path(temp_path).unlink(missing_ok=True)


def main():
    args = parse_args()
    replacements = parse_replacements(args.replace)

    with zipfile.ZipFile(args.jar, "r") as jar_file:
        class_bytes = jar_file.read(args.class_path)

    patched_class_bytes, status_lines, changed = patch_class_bytes(class_bytes, replacements)
    if changed:
        rewrite_jar(args.jar, args.class_path, patched_class_bytes)

    for line in status_lines:
        print(line)

    print("RESULT=changed" if changed else "RESULT=unchanged")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
#!/usr/bin/env python3
"""Extract A/B OTA payload images with SHA-256 verification.

This is the project-local replacement for payload_dumper 0.2.2's macOS
multiprocessing failure. It intentionally stays single-process and explicit:
every operation hash and the final partition hash are verified.

Requires: payload_dumper (only for its update_metadata_pb2 protobuf module).

Example:
    python3 tools/extract_payload.py \
        --zip CPH2415_15.0.0.1901_EX01.zip \
        --output vendor_extract/images \
        --partitions boot,dtbo,vendor_boot,vendor,vendor_dlkm,odm,odm_dlkm,system,system_ext,product,my_product

    python3 tools/extract_payload.py --zip ... --list
"""
import argparse
import bz2
import hashlib
import lzma
import struct
import sys
import zipfile
from pathlib import Path

from payload_dumper import update_metadata_pb2 as um

DEFAULT_PARTITIONS = [
    "vendor", "odm", "system", "system_ext", "product", "my_product",
    "vendor_boot", "vendor_dlkm", "odm_dlkm", "boot", "dtbo",
]

ZERO = um.InstallOperation.Type.ZERO
REPLACE = um.InstallOperation.Type.REPLACE
REPLACE_BZ = um.InstallOperation.Type.REPLACE_BZ
REPLACE_XZ = um.InstallOperation.Type.REPLACE_XZ
SOURCE_COPY = um.InstallOperation.Type.SOURCE_COPY


def load_manifest(zip_path):
    zf = zipfile.ZipFile(zip_path)
    pf = zf.open("payload.bin")
    magic = pf.read(4)
    if magic != b"CrAU":
        raise SystemExit(f"bad payload magic: {magic!r}")
    major, minor = struct.unpack(">II", pf.read(8))
    manifest_size, manifest_sig_size = struct.unpack(">QI", pf.read(12))
    metadata_size = 0
    if (major, minor) >= (2, 0):
        metadata_size = struct.unpack(">Q", pf.read(8))[0]
    data_base = 24 + manifest_size + manifest_sig_size + metadata_size

    manifest = um.DeltaArchiveManifest()
    manifest.ParseFromString(pf.read(manifest_size))
    return zf, pf, manifest, data_base, (major, minor)


def extract_partition(pf, part, block_size, data_base, out_dir):
    name = part.partition_name
    info = part.new_partition_info
    size = info.size
    out_path = out_dir / f"{name}.img"
    print(f"[{name}] {size / 1e9:.2f} GB, {len(part.operations)} ops", flush=True)

    h = hashlib.sha256()
    with open(out_path, "wb+") as out:
        out.truncate(size)
        for i, op in enumerate(part.operations):
            op_name = um.InstallOperation.Type.Name(op.type)
            if op.type == SOURCE_COPY:
                raise SystemExit(
                    f"[{name}] op{i}: SOURCE_COPY found; this tool supports full OTA only"
                )
            if op.type == ZERO:
                for ext in op.dst_extents:
                    out.seek(ext.start_block * block_size)
                    chunk = b"\0" * (ext.num_blocks * block_size)
                    out.write(chunk)
                continue

            pf.seek(data_base + op.data_offset)
            data = pf.read(op.data_length)
            if op.data_sha256_hash:
                if hashlib.sha256(data).digest() != op.data_sha256_hash:
                    raise SystemExit(f"[{name}] op{i}: operation data hash mismatch")

            if op.type == REPLACE:
                blob = data
            elif op.type == REPLACE_BZ:
                blob = bz2.decompress(data)
            elif op.type == REPLACE_XZ:
                blob = lzma.decompress(data)
            else:
                raise SystemExit(f"[{name}] op{i}: unsupported type {op_name}")

            offset = 0
            for ext in op.dst_extents:
                length = ext.num_blocks * block_size
                out.seek(ext.start_block * block_size)
                out.write(blob[offset:offset + length])
                offset += length
            if offset != len(blob):
                raise SystemExit(
                    f"[{name}] op{i}: blob {len(blob)} != extents {offset}"
                )

        out.seek(0)
        for chunk in iter(lambda: out.read(1024 * 1024), b""):
            h.update(chunk)

    if info.hash:
        if h.digest() != info.hash:
            raise SystemExit(f"[{name}] final partition hash mismatch")
    print(f"[{name}] done -> {out_path}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zip", required=True, type=Path, help="OTA zip path")
    parser.add_argument("--output", type=Path, default=Path("vendor_extract/images"))
    parser.add_argument(
        "--partitions",
        default=",".join(DEFAULT_PARTITIONS),
        help="comma-separated partition names (default: common bring-up set)",
    )
    parser.add_argument("--list", action="store_true", help="list partitions and exit")
    args = parser.parse_args()

    zf, pf, manifest, data_base, version = load_manifest(args.zip)
    print(
        f"payload v{version[0]}.{version[1]} block_size={manifest.block_size} "
        f"partitions={len(manifest.partitions)}"
    )
    if args.list:
        for part in manifest.partitions:
            print(f"{part.partition_name}\t{part.new_partition_info.size}")
        return

    wanted = {p.strip() for p in args.partitions.split(",") if p.strip()}
    found = {part.partition_name for part in manifest.partitions}
    missing = wanted - found
    if missing:
        raise SystemExit(f"partitions not present in payload: {sorted(missing)}")

    args.output.mkdir(parents=True, exist_ok=True)
    for part in manifest.partitions:
        if part.partition_name in wanted:
            extract_partition(pf, part, manifest.block_size, data_base, args.output)

    print("ALL DONE")


if __name__ == "__main__":
    main()

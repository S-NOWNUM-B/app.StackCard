#!/usr/bin/env python3
"""Проверка LCOV Flutter без исключения runtime-файлов или изменения denominator."""
import argparse
import hashlib
import json
from pathlib import Path


def report(lcov: Path, project: Path) -> dict:
    project = project.resolve()
    runtime = project / "lib"
    files: dict[str, dict[int, int]] = {}
    current = None
    for row in lcov.read_text(encoding="utf-8").splitlines():
        if row.startswith("SF:"):
            if current is not None:
                raise ValueError("Missing end_of_record")
            source = (project / row[3:].replace("\\", "/")).resolve()
            if not source.is_relative_to(runtime) or not source.is_file():
                raise ValueError(f"Invalid runtime source: {row[3:]}")
            current = source.relative_to(project).as_posix()
            files.setdefault(current, {})
        elif row.startswith("DA:"):
            if current is None:
                raise ValueError("DA without SF")
            line, hits = map(int, row[3:].split(",")[:2])
            if line < 1 or hits < 0:
                raise ValueError("Invalid DA")
            files[current][line] = max(files[current].get(line, 0), hits)
        elif row == "end_of_record":
            if current is None:
                raise ValueError("end_of_record without SF")
            current = None
    if current is not None:
        raise ValueError("Missing final end_of_record")
    total = sum(len(lines) for lines in files.values())
    if not total:
        raise ValueError("LCOV contains no executable lines")
    covered = sum(hits > 0 for lines in files.values() for hits in lines.values())
    sources = sorted(runtime.rglob("*.dart"))
    digest = hashlib.sha256()
    for source in sources:
        digest.update(source.relative_to(project).as_posix().encode())
        digest.update(b"\0" + source.read_bytes() + b"\0")
    return {
        "coveredLines": covered,
        "executableLines": total,
        "linePercent": 100 * covered / total,
        "reportedFiles": len(files),
        "runtimeDartFiles": len(sources),
        "unreportedFiles": sorted(
            source.relative_to(project).as_posix()
            for source in sources
            if source.relative_to(project).as_posix() not in files
        ),
        "runtimeSourceSha256": digest.hexdigest(),
        "lcovSha256": hashlib.sha256(lcov.read_bytes()).hexdigest(),
        "scope": "Executable DA lines reported by Flutter; no filters. Unreported files listed separately.",
    }


def above_minimum(value: dict, minimum: float) -> bool:
    return value["coveredLines"] * 100 > minimum * value["executableLines"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lcov", type=Path)
    parser.add_argument("--project", type=Path, default=Path("apps/mobile"))
    parser.add_argument("--minimum", type=float, default=40)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if not 0 <= args.minimum <= 100:
        parser.error("minimum must be between 0 and 100")
    try:
        value = report(args.lcov, args.project)
    except (ValueError, OSError) as error:
        parser.error(str(error))
    value["minimumExclusive"] = args.minimum
    value["passed"] = above_minimum(value, args.minimum)
    if args.output:
        args.output.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"LCOV: {value['coveredLines']}/{value['executableLines']} = {value['linePercent']:.2f}%; "
          f">{args.minimum:g}%: {'PASS' if value['passed'] else 'FAIL'}; "
          f"unreported Dart files: {len(value['unreportedFiles'])}")
    return 0 if value["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

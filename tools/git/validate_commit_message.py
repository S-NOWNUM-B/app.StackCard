#!/usr/bin/env python3
"""Нативная проверка сообщения по prospective Git index, без зависимостей Codex."""

import os
from pathlib import Path
import re
import subprocess
import sys


def git(*args, input_bytes=None, optional=False):
    result = subprocess.run(
        ["git", *args], input=input_bytes, capture_output=True, timeout=15,
    )
    if result.returncode:
        if optional and result.returncode == 1:
            return None
        raise ValueError("Не удалось прочитать Git index/config; commit отклонён.")
    return result.stdout


def expected_paths(mode):
    if mode not in ("commit", "amend"):
        raise ValueError("STACKCARD_COMMIT_MODE допускает только commit или amend.")
    if git("ls-files", "--unmerged", "-z"):
        raise ValueError("Сначала разреши конфликты в index.")
    head = git("rev-parse", "--verify", "--quiet", "HEAD", optional=True)
    base = head.decode().strip() if head else None
    if mode == "amend":
        if not head:
            raise ValueError("Для amend нужен существующий HEAD.")
        parents = git("rev-list", "--parents", "-n", "1", "HEAD").split()[1:]
        if len(parents) > 1:
            raise ValueError("Amend merge commit не входит в линейный workflow StackCard.")
        base = parents[0].decode() if parents else None
    if base is None:
        # write-tree исключает intent-to-add: такие записи не входят в commit.
        # Историю/index он не меняет; создаёт только prospective tree object.
        tree = git("write-tree").decode().strip()
        raw = git("ls-tree", "-r", "--name-only", "-z", tree)
    else:
        raw = git(
            "diff", "--cached", "--name-only", "--no-renames",
            "--ignore-submodules=none", "--ita-invisible-in-index", "-z", base, "--",
        )
    paths = {os.fsdecode(path) for path in raw.split(b"\0") if path}
    if not paths:
        raise ValueError(
            "В index нет изменений. Для исправления сообщения используй "
            "STACKCARD_COMMIT_MODE=amend git commit --amend -F <message-file>."
        )
    return paths


def message_error(message, expected):
    lines = message.rstrip("\r\n").splitlines()
    header = lines[0] if lines else ""
    match = re.fullmatch(
        r"(feat|fix|docs|style|refactor|test|chore)\([a-z0-9][a-z0-9/_-]*\): (.+)", header,
    )
    if not match:
        return "Subject: type(scope): русское описание; type/scope lowercase."
    description = match.group(2)
    if description != description.lower() or description.endswith(".") or not re.search(r"[а-яё]", description):
        return "Description должен быть на русском, lowercase, без точки в конце."
    words = description.split()
    if not 7 <= len(words) <= 25:
        return "Description должен содержать 7–25 слов."
    if not re.fullmatch(r"[а-яё]+л|вынес|перенёс|принёс|унёс|снёс", words[0].strip(",:;")):
        return "Начни description с глагола прошедшего времени: добавил, исправил, вынес."
    if len(lines) < 3 or lines[1] or not lines[2]:
        return "Body обязателен: одна пустая строка после subject, затем - path: описание."
    paths = set()
    for line in lines[2:]:
        # Longest literal match поддерживает пробелы и ': ' в имени файла.
        candidates = [path for path in expected if line.startswith("- " + path + ": ")]
        path = max(candidates, key=len) if candidates else None
        if path is None:
            return "Лишний файл или неверный формат body: " + line
        detail = line[len(path) + 4:]
        if not detail.strip():
            return "Отсутствует описание файла: " + path
        if path in paths:
            return "Повторяется файл в body: " + path
        paths.add(path)
    missing = sorted(expected - paths)
    return "В body отсутствуют файлы: " + ", ".join(missing) if missing else None


def canonical_message(path):
    # Удаляем Git editor comments и сохраняем проверенный текст в самом message file.
    # Поэтому дальнейший --cleanup=verbatim тоже получает проверенное сообщение.
    for key in ("core.commentChar", "core.commentString"):
        value = git("config", "--get", key, optional=True)
        if value is not None and value.decode().strip() != "#":
            raise ValueError("Для commit-msg требуется стандартный Git comment prefix '#'.")
    return git("stripspace", "--strip-comments", input_bytes=path.read_bytes()).decode("utf-8")


def main():
    try:
        if len(sys.argv) != 2:
            raise ValueError("Использование: validate_commit_message.py <message-file>.")
        path = Path(sys.argv[1])
        message = canonical_message(path)
        error = message_error(message, expected_paths(os.environ.get("STACKCARD_COMMIT_MODE", "commit")))
        if error:
            raise ValueError(error)
        with path.open("w", encoding="utf-8", newline="\n") as output:
            output.write(message)
    except (OSError, UnicodeError, ValueError, subprocess.TimeoutExpired) as error:
        print("StackCard commit-msg: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

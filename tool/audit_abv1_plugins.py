#!/usr/bin/env python3
"""Audit API usage across repositories listed by the ABv1 plugin store."""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
import tarfile
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import PurePosixPath


DEFAULT_INDEX = (
    "https://raw.githubusercontent.com/AstralSightStudios/"
    "AstroBox-Plugin-Repo/refs/heads/main/index.txt"
)
API_GROUPS = {
    "config": ("readConfig", "writeConfig"),
    "debug": ("sendRaw",),
    "device": (
        "getDeviceList",
        "getDeviceState",
        "modifyDeviceState",
        "disconnectDevice",
    ),
    "event": ("addEventListener", "removeEventListener", "sendEvent"),
    "filesystem": ("pickFile", "readFile", "unloadFile"),
    "installer": (
        "addThirdPartyAppToQueue",
        "addWatchFaceToQueue",
        "addFirmwareToQueue",
    ),
    "interconnect": ("sendQAICMessage",),
    "lifecycle": ("onLoad",),
    "native": ("regNativeFun",),
    "network": ("fetch",),
    "provider": ("registerCommunityProvider",),
    "thirdpartyapp": ("launchQA", "getThirdPartyAppList"),
    "ui": ("updatePluginSettingsUI", "openPageWithNodes", "openPageWithUrl"),
}
SOURCE_SUFFIXES = {".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx"}
IGNORED_PARTS = {
    ".git",
    "build",
    "dist",
    "node_modules",
    "out",
    "target",
    "vendor",
}
RAW_GITHUB_RE = re.compile(
    r"^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/refs/heads/([^/]+)/(.*)$"
)


@dataclass(frozen=True)
class Repository:
    base_url: str
    owner: str | None
    name: str | None
    branch: str | None
    prefix: str


def fetch_bytes(url: str, timeout: float) -> bytes:
    for attempt in range(3):
        request = urllib.request.Request(
            url,
            headers={"User-Agent": "ZeroBox-ABv1-Auditor/1.0"},
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.read()
        except (OSError, urllib.error.URLError):
            if attempt == 2:
                raise
            time.sleep(0.5 * (attempt + 1))

    raise AssertionError("unreachable")


def fetch_text(url: str, timeout: float) -> str:
    return fetch_bytes(url, timeout).decode("utf-8-sig", errors="replace")


def lines(text: str) -> list[str]:
    return [
        line.strip()
        for line in text.splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


def directory_url(url: str) -> str:
    return url if url.endswith("/") else f"{url}/"


def parse_repository(url: str) -> Repository:
    base_url = directory_url(url)
    match = RAW_GITHUB_RE.match(base_url)
    if match is None:
        return Repository(base_url, None, None, None, "")
    owner, name, branch, prefix = match.groups()
    return Repository(base_url, owner, name, branch, prefix.strip("/"))


def load_source_archive(repository: Repository, timeout: float) -> dict[str, str]:
    if not repository.owner or not repository.name or not repository.branch:
        return {}
    archive_url = (
        f"https://codeload.github.com/{repository.owner}/{repository.name}/"
        f"tar.gz/refs/heads/{urllib.parse.quote(repository.branch, safe='')}"
    )
    result: dict[str, str] = {}
    with tarfile.open(fileobj=io.BytesIO(fetch_bytes(archive_url, timeout)), mode="r:gz") as archive:
        for member in archive.getmembers():
            if not member.isfile() or member.size > 8 * 1024 * 1024:
                continue
            parts = PurePosixPath(member.name).parts
            relative_parts = parts[1:]
            if repository.prefix:
                prefix_parts = PurePosixPath(repository.prefix).parts
                if relative_parts[: len(prefix_parts)] != prefix_parts:
                    continue
                relative_parts = relative_parts[len(prefix_parts) :]
            path = PurePosixPath(*relative_parts)
            if path.suffix.lower() not in SOURCE_SUFFIXES:
                continue
            if any(part in IGNORED_PARTS for part in path.parts):
                continue
            extracted = archive.extractfile(member)
            if extracted is None:
                continue
            result[path.as_posix()] = extracted.read().decode("utf-8", errors="replace")
    return result


def detect_calls(text: str) -> set[str]:
    calls: set[str] = set()
    for group, methods in API_GROUPS.items():
        for method in methods:
            pattern = rf"\bAstroBox\s*\.\s*{re.escape(group)}\s*\.\s*{re.escape(method)}\b"
            if re.search(pattern, text):
                calls.add(f"{group}.{method}")
    return calls


def source_for_plugin(
    archive: dict[str, str], folder: str, single_plugin_repository: bool
) -> tuple[dict[str, str], str]:
    folder_path = PurePosixPath(folder.strip("/"))
    candidates = {
        path: text
        for path, text in archive.items()
        if PurePosixPath(path).is_relative_to(folder_path)
    }
    source_candidates = {
        path: text
        for path, text in candidates.items()
        if "src" in PurePosixPath(path).parts
    }
    if source_candidates:
        return source_candidates, "source"
    if single_plugin_repository:
        repository_sources = {
            path: text
            for path, text in archive.items()
            if "src" in PurePosixPath(path).parts
        }
        if repository_sources:
            return repository_sources, "repository-source"
    return {}, "manifest-only"


def audit_repository(
    repository: Repository, timeout: float
) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    label = (
        f"{repository.owner}/{repository.name}@{repository.branch}"
        if repository.owner
        else repository.base_url
    )
    plugins: list[dict[str, object]] = []
    failures: list[dict[str, str]] = []
    try:
        folders = lines(
            fetch_text(urllib.parse.urljoin(repository.base_url, "index.txt"), timeout)
        )
        archive = load_source_archive(repository, timeout)
    except Exception as error:
        return [], [{"repository": label, "error": str(error)}]

    for folder in folders:
        manifest_url = urllib.parse.urljoin(
            repository.base_url, f"{folder}/manifest.json"
        )
        try:
            manifest = json.loads(fetch_text(manifest_url, timeout))
            if not isinstance(manifest, dict):
                raise ValueError("manifest root is not an object")
            permissions = sorted(
                {str(value) for value in manifest.get("permissions", [])}
            )
            files, scan_mode = source_for_plugin(
                archive, folder, single_plugin_repository=len(folders) == 1
            )
            calls_by_file = {
                path: sorted(calls)
                for path, text in files.items()
                if (calls := detect_calls(text))
            }
            calls = sorted(
                {call for values in calls_by_file.values() for call in values}
            )
            called_groups = sorted({call.split(".", 1)[0] for call in calls})
            plugins.append(
                {
                    "name": str(manifest.get("name", folder)),
                    "version": str(manifest.get("version", "")),
                    "repository": label,
                    "folder": folder,
                    "manifest_url": manifest_url,
                    "permissions": permissions,
                    "calls": calls,
                    "calls_by_file": calls_by_file,
                    "scan_mode": scan_mode,
                    "undeclared_calls": sorted(
                        set(called_groups) - set(permissions)
                    ),
                    "unused_permissions": sorted(
                        set(permissions) - set(called_groups)
                    ),
                }
            )
        except Exception as error:
            failures.append(
                {"repository": label, "plugin": folder, "error": str(error)}
            )
    return plugins, failures


def audit(index_url: str, timeout: float) -> dict[str, object]:
    repositories = [parse_repository(url) for url in lines(fetch_text(index_url, timeout))]
    plugins: list[dict[str, object]] = []
    failures: list[dict[str, str]] = []

    with ThreadPoolExecutor(max_workers=min(6, len(repositories) or 1)) as executor:
        futures = {
            executor.submit(audit_repository, repository, timeout): repository
            for repository in repositories
        }
        for future in as_completed(futures):
            repository_plugins, repository_failures = future.result()
            plugins.extend(repository_plugins)
            failures.extend(repository_failures)

    permission_counts = Counter(
        permission for plugin in plugins for permission in plugin["permissions"]
    )
    call_counts = Counter(call for plugin in plugins for call in plugin["calls"])
    return {
        "index": index_url,
        "repository_count": len(repositories),
        "plugin_count": len(plugins),
        "permission_counts": dict(sorted(permission_counts.items())),
        "call_counts": dict(sorted(call_counts.items())),
        "plugins": sorted(plugins, key=lambda plugin: str(plugin["name"]).casefold()),
        "failures": failures,
    }


def print_report(report: dict[str, object]) -> None:
    print(
        f"ABv1 audit: {report['plugin_count']} plugins from "
        f"{report['repository_count']} repositories"
    )
    print("\nDeclared permissions:")
    for permission, count in report["permission_counts"].items():
        print(f"  {permission:16} {count}")
    print("\nDetected direct calls:")
    for call, count in report["call_counts"].items():
        print(f"  {call:42} {count}")
    print("\nPlugins:")
    for plugin in report["plugins"]:
        permissions = ", ".join(plugin["permissions"]) or "-"
        calls = ", ".join(plugin["calls"]) or "-"
        print(f"  {plugin['name']} {plugin['version']} [{plugin['repository']}]")
        print(f"    permissions: {permissions}")
        print(f"    calls ({plugin['scan_mode']}): {calls}")
        if plugin["undeclared_calls"]:
            print(f"    undeclared groups: {', '.join(plugin['undeclared_calls'])}")
        if plugin["unused_permissions"]:
            print(f"    declared but not detected: {', '.join(plugin['unused_permissions'])}")
    if report["failures"]:
        print("\nFailures:", file=sys.stderr)
        for failure in report["failures"]:
            print(f"  {failure}", file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index", default=DEFAULT_INDEX, help="ABv1 top-level index URL")
    parser.add_argument("--timeout", type=float, default=30, help="HTTP timeout in seconds")
    parser.add_argument("--json", action="store_true", help="emit JSON instead of text")
    args = parser.parse_args()
    try:
        report = audit(args.index, args.timeout)
    except (OSError, ValueError, urllib.error.URLError) as error:
        print(f"audit failed: {error}", file=sys.stderr)
        return 1
    if args.json:
        json.dump(report, sys.stdout, ensure_ascii=False, indent=2)
        print()
    else:
        print_report(report)
    return 2 if report["failures"] else 0


if __name__ == "__main__":
    raise SystemExit(main())

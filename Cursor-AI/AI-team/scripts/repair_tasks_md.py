import argparse
import json
import re
from pathlib import Path


def _load_progress_tasks(progress_json_path: Path) -> dict[str, dict]:
    data = json.loads(progress_json_path.read_text(encoding="utf-8"))
    tasks = data.get("tasks") or []
    out: dict[str, dict] = {}
    for t in tasks:
        tid = str(t.get("id") or "").strip()
        if not tid:
            continue
        out[tid] = t
    return out


def _normalize_newlines(s: str) -> str:
    return s.replace("\r\n", "\n").replace("\r", "\n")


def repair_tasks_md_text(text: str) -> str:
    """
    Repair common corruption patterns in tasks.md caused by line-joining field updates.
    This is intentionally conservative: it only inserts newlines where markers are clearly glued.
    """
    text = _normalize_newlines(text)

    # 1) Ensure task headers don't get glued mid-line: "...### task-012" -> "...\n\n### task-012"
    text = re.sub(r"(?m)([^\n])###\s*(task-\d+)\s*$", r"\1\n\n### \2", text)
    text = re.sub(r"(?m)([^\n])###\s*(task-\d+)\b", r"\1\n\n### \2", text)

    # 2) Ensure common field markers end with a newline if they are immediately followed by another marker.
    # Example: "Artifacts: foo- Dependencies: bar" -> "Artifacts: foo\n- Dependencies: bar"
    markers = [
        "Artifacts:",
        "Status:",
        "Progress:",
        "Completed:",
        "Started:",
        "Created:",
        "Assigned Agent:",
        "Blocker:",
        "Blocker Type:",
    ]
    next_marker = r"(?:###\s*task-\d+|-+\s*(?:Title|Description|Estimated Hours|Dependencies|Acceptance Criteria)|Status:|Progress:|Artifacts:|Blocker:|Blocker Type:|Assigned Agent:|Created:|Started:|Completed:)"
    for m in markers:
        text = re.sub(
            rf"(?m)({re.escape(m)}[^\n]*?)(?={next_marker})",
            r"\1\n",
            text,
        )

    return text


def fill_missing_title_description(text: str, progress_tasks: dict[str, dict]) -> str:
    """
    Ensure every task block has - Title: and - Description:. If missing, fill from progress JSON.
    """
    text = _normalize_newlines(text)

    def repl(match: re.Match) -> str:
        header = match.group(1)
        body = match.group(2)
        tid = header.strip().split(maxsplit=1)[-1].strip()
        t = progress_tasks.get(tid) or {}
        title = str(t.get("title") or tid).strip()
        desc = str(t.get("description") or "").strip()

        has_title = re.search(r"(?m)^\s*-?\s*Title:\s*\S+", body) is not None
        has_desc = re.search(r"(?m)^\s*-?\s*Description:\s*\S+", body) is not None

        inserts = []
        if not has_title:
            inserts.append(f"- Title: {title}")
        if not has_desc and desc:
            inserts.append(f"- Description: {desc}")

        if inserts:
            body = "\n".join(inserts) + "\n" + body.lstrip("\n")
        return f"{header}\n{body}"

    pattern = r"(?ms)^(###\s*task-\d+)\s*\n(.*?)(?=^###\s*task-\d+\s*$|\Z)"
    return re.sub(pattern, repl, text)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tasks-md", required=True, help="Path to tasks.md")
    ap.add_argument(
        "--progress-json",
        required=False,
        help="Optional progress snapshot JSON that contains task titles/descriptions to backfill",
    )
    ap.add_argument(
        "--rebuild-from-progress-json",
        action="store_true",
        help="Rebuild tasks.md completely from --progress-json (overwrites existing file).",
    )
    ap.add_argument(
        "--reset-noncompleted",
        action="store_true",
        help="When rebuilding, set all non-completed tasks to Status: pending / Progress: 0 and clear Blocker.",
    )
    args = ap.parse_args()

    tasks_path = Path(args.tasks_md)
    if args.rebuild_from_progress_json:
        if not args.progress_json:
            raise SystemExit("--rebuild-from-progress-json requires --progress-json")
        progress_path = Path(args.progress_json)
        progress_tasks = _load_progress_tasks(progress_path)
        # Sort by numeric task id where possible.
        def sort_key(tid: str) -> tuple[int, str]:
            m = re.search(r"task-(\d+)", tid)
            return (int(m.group(1)) if m else 10**9, tid)

        lines: list[str] = []
        for tid in sorted(progress_tasks.keys(), key=sort_key):
            t = progress_tasks[tid] or {}
            title = str(t.get("title") or tid).strip()
            desc = str(t.get("description") or "").strip()
            status = str(t.get("status") or "pending").strip().lower()
            progress = int(t.get("progress") or 0)
            deps = t.get("dependencies") or []
            est = t.get("estimated_hours") or 1.0
            artifacts = t.get("artifacts") or []
            blocker = t.get("blocker_message")

            if args.reset_noncompleted and status != "completed":
                status = "pending"
                progress = 0
                blocker = None

            lines.append(f"### {tid}")
            if blocker:
                lines.append(f"Blocker: {blocker}")
            lines.append(f"- Title: {title}")
            if desc:
                lines.append(f"- Description: {desc}")
            lines.append(f"Status: {status}")
            lines.append(f"Progress: {progress}")
            lines.append(f"- Estimated Hours: {est}")
            if deps:
                lines.append(f"- Dependencies: {', '.join(deps)}")
            else:
                lines.append("- Dependencies: none")
            if artifacts:
                lines.append(f"Artifacts: {', '.join(artifacts)}")
            lines.append("- Acceptance Criteria:")
            # Minimal acceptance criteria: keep the file self-contained and parseable.
            if artifacts:
                for a in artifacts[:10]:
                    lines.append(f"  - Artifact exists: {a}")
            else:
                lines.append("  - Task completes successfully")
            lines.append("")  # blank line between tasks

        text = "\n".join(lines).rstrip() + "\n"
    else:
        text = tasks_path.read_text(encoding="utf-8", errors="replace")
        text = repair_tasks_md_text(text)

        if args.progress_json:
            progress_path = Path(args.progress_json)
            progress_tasks = _load_progress_tasks(progress_path)
            text = fill_missing_title_description(text, progress_tasks)

    # Write back using platform default newlines (Windows tools will still read LF fine).
    tasks_path.write_text(text, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())



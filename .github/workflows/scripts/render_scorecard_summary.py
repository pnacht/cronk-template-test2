"""Render OpenSSF Scorecard results as a Markdown table in GITHUB_STEP_SUMMARY."""

import json
import os
import re
import urllib.request
from typing import Any, Dict, List, Optional


def fetch_api_report(repo: str) -> Optional[Dict[str, Any]]:
    if not repo:
        return None
    api_url = f"https://api.securityscorecards.dev/projects/github.com/{repo}"
    try:
        req = urllib.request.Request(
            api_url, headers={"Accept": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None


def format_api_rows(api_data: Dict[str, Any]) -> List[str]:
    agg_score = api_data.get("score", "N/A")
    rows = [
        f"### Aggregate Score: `{agg_score} / 10`",
        "",
        "| Check | Score | Reason |",
        "| :--- | :---: | :--- |",
    ]
    checks = sorted(
        api_data.get("checks", []), key=lambda item: item.get("name", "")
    )
    for chk in checks:
        name = chk.get("name", "Unknown")
        score = chk.get("score", -1)
        if isinstance(score, int) and score >= 0:
            score_str = f"{score}/10"
        else:
            score_str = f"{score} (skipped)"
        reason = (chk.get("reason") or "").replace("|", "\\|").replace("\n", " ")
        rows.append(f"| `{name}` | `{score_str}` | {reason} |")
    return rows


def format_sarif_rows(sarif_path: str) -> List[str]:
    with open(sarif_path, "r", encoding="utf-8") as fh:
        sarif = json.load(fh)
    run_obj = (sarif.get("runs") or [{}])[0]
    rules = run_obj.get("tool", {}).get("driver", {}).get("rules") or []
    results = run_obj.get("results") or []

    findings_by_rule: Dict[str, List[str]] = {}
    for res in results:
        rid = res.get("ruleId", "")
        msg = (res.get("message", {}).get("text") or "").strip()
        findings_by_rule.setdefault(rid, []).append(msg)

    rows = [
        "| Check | Status | Details |",
        "| :--- | :---: | :--- |",
    ]
    for rule in sorted(rules, key=lambda item: item.get("id", "")):
        rid = rule.get("id", "Unknown")
        msgs = findings_by_rule.get(rid, [])
        if not msgs:
            status = "10/10 (Pass)"
            detail = "No issues detected"
        else:
            joined = "; ".join(msgs).replace("|", "\\|").replace("\n", " ")
            match = re.search(r"score is (-?\d+)", joined)
            status = f"{match.group(1)}/10" if match else "Alert"
            detail = joined
        rows.append(f"| `{rid}` | `{status}` | {detail} |")
    return rows


def main() -> None:
    repo = os.environ.get("REPO", "")
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    viewer_url = f"https://scorecard.dev/viewer/?uri=github.com/{repo}"

    lines = [
        "## OpenSSF Scorecard Supply-Chain Security Report",
        "",
        f"**Interactive Viewer:** [{viewer_url}]({viewer_url})",
        "",
    ]

    api_data = fetch_api_report(repo)
    if api_data and "checks" in api_data:
        lines.extend(format_api_rows(api_data))
    elif os.path.exists("results.sarif"):
        lines.extend(format_sarif_rows("results.sarif"))
    else:
        lines.append("_No `results.sarif` artifact found._")

    output = "\n".join(lines) + "\n"
    print(output)
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as out:
            out.write(output)


if __name__ == "__main__":
    main()

"""Run simulated acceptance cases in genuinely fresh native Lua 5.0 processes."""

from pathlib import Path
import argparse, json, subprocess, tempfile, re

p = argparse.ArgumentParser()
p.add_argument("--addon", required=True)
p.add_argument("--lua50", required=True)
fixture_args = p.add_mutually_exclusive_group(required=True)
fixture_args.add_argument("--client")
fixture_args.add_argument("--api")
p.add_argument("--report", required=True)
p.add_argument("--smoke", action="store_true")
a = p.parse_args()
addon = Path(a.addon).resolve()
lua50 = Path(a.lua50).resolve()
test_root = Path(__file__).resolve().parent.parent
import sys

sys.path.insert(0, str(test_root.parent / "tools"))
from client_fixture import read_fixture

api_source, fixture_metadata = read_fixture(a.client, a.api)
classes = [
    "warrior",
    "paladin",
    "hunter",
    "rogue",
    "priest",
    "shaman",
    "mage",
    "warlock",
    "druid",
]
results = ["defeat", "left", "victory"]
if a.smoke:
    classes = ["rogue"]
    results = ["victory"]
report = {
    "runtime": "Lua 5.0.3 native; new process per stage; game UI simulated",
    "cases": [],
    "assertions": 0,
    "freshProcesses": 0,
    "fixture": fixture_metadata,
    "inGamePlaythroughsPerformed": False,
}
with tempfile.TemporaryDirectory(prefix="azerothstats-acceptance-") as tmp:
    temp = Path(tmp)
    api = temp / "client-api.lua"
    api.write_text(api_source, encoding="utf-8")
    index = 0
    for cls in classes:
        for result in results:
            index += 1
            input_path = "-"
            case = {"class": cls, "result": result, "stages": []}
            for stage in [1, 2, 3]:
                output = temp / (cls + "-" + result + "-" + str(stage) + ".lua")
                call = [
                    str(lua50),
                    "tests/release_runner.lua",
                    str(addon),
                    str(api),
                    input_path,
                    str(output),
                    str(stage),
                    cls,
                    result,
                    str(index),
                ]
                run = subprocess.run(
                    call,
                    cwd=test_root,
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    timeout=30,
                )
                assert run.returncode == 0, (cls, result, stage, run.stdout, run.stderr)
                match = re.search(
                    r"RELEASE_CASE_OK\s+\w+\s+\w+\s+\d+\s+(\d+)", run.stdout
                )
                assert match, run.stdout
                count = int(match[1])
                case["stages"].append(
                    {
                        "stage": stage,
                        "assertions": count,
                        "savedBytes": output.stat().st_size,
                    }
                )
                report["assertions"] += count
                report["freshProcesses"] += 1
                input_path = str(output)
            report["cases"].append(case)
report["passed"] = True
Path(a.report).parent.mkdir(parents=True, exist_ok=True)
Path(a.report).write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in report.items() if k != "cases"}, indent=2))

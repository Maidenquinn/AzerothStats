"""Archive a clean, committed source revision for manual review; never publish it."""

from pathlib import Path
import argparse
import hashlib
import subprocess
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output", type=Path, default=Path("release-assets/approval-review")
    )
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent

    def git(*arguments):
        return subprocess.check_output(["git", *arguments], cwd=root)

    assert not git(
        "status", "--porcelain"
    ), "Commit/review source changes before archiving"
    revision = git("rev-parse", "HEAD").decode().strip()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    archive = output / ("AzerothStats-source-review-" + revision[:12] + ".zip")
    subprocess.run(
        [
            "git",
            "archive",
            "--format=zip",
            "--prefix=AzerothStats-source/",
            "--output=" + str(archive),
            revision,
        ],
        cwd=root,
        check=True,
    )
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        for name in bundle.namelist():
            path = Path(name)
            assert ".." not in path.parts and not path.is_absolute()
            assert path.suffix.lower() not in {".exe", ".dll", ".sav", ".zip"}, name
            assert not any(
                part in {".git", "saved", "SavedVariables", ".env"}
                for part in path.parts
            ), name
        assert "AzerothStats-source/docs/REVIEWER-GUIDE.md" in bundle.namelist()
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(
        digest + "  " + archive.name + "\n", encoding="utf-8"
    )
    archive.with_suffix(".revision.txt").write_text(revision + "\n", encoding="utf-8")
    print(archive)
    print(digest)


if __name__ == "__main__":
    main()

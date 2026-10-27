"""Load an explicitly selected trusted API fixture for developer-only tests.

The recommended review path uses a fixture supplied by the game team. Reading
an installed executable is an optional legacy compatibility path, never a write.
No fixture, executable bytes or personal save is bundled in player artifacts.
"""

from pathlib import Path
import hashlib


def read_fixture(client=None, api=None):
    if api is not None:
        raw = Path(api).read_bytes()
        assert len(raw) <= 2000000, "API fixture is unexpectedly large"
        return raw.decode("utf-8-sig"), {
            "mode": "trusted-api-file",
            "apiSha256": hashlib.sha256(raw).hexdigest(),
        }
    assert client is not None
    binary = Path(client).read_bytes()
    start_marker = b"-- Azeroth Survivors: the run for addons"
    end_marker = b'AZSApiFrame:SetScript("OnEvent", AZS_ApiOnEvent);'
    start = binary.find(start_marker)
    assert (
        start >= 0
    ), "Client API marker changed; request a trusted --api fixture from the game team"
    end = binary.find(end_marker, start)
    assert (
        end >= 0
    ), "Client API end marker changed; request a trusted --api fixture from the game team"
    end += len(end_marker)
    raw = binary[start:end]
    return raw.decode("utf-8"), {
        "mode": "read-only-client",
        "sha256": hashlib.sha256(binary).hexdigest(),
        "apiSha256": hashlib.sha256(raw).hexdigest(),
        "apiOffset": start,
        "apiEnd": end,
    }

"""Optional read-only check against an installed Unsloth cache-routing module.

Run through Probe-Unsloth-Cache.ps1. No app server, database, model scan or
download is started. Only the installed cache-settings module is imported.
"""

import importlib.util
import json
import os
from pathlib import Path
import sys

backend = Path(sys.argv[1])
source = backend / "utils" / "hf_cache_settings.py"
spec = importlib.util.spec_from_file_location("launcher_cache_probe", source)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
paths = module.get_hf_cache_paths()
from huggingface_hub import constants

checks = {
    "explicit_cache_selected": paths.source == "environment",
    "hub_path_matches_launcher": paths.hub_cache == Path(os.environ["HF_HUB_CACHE"]).resolve(),
    "auxiliary_cache_matches_launcher": paths.xet_cache == Path(os.environ["HF_XET_CACHE"]).resolve(),
    "token_is_under_private_home": Path(os.environ["HF_TOKEN_PATH"]).parent == Path(os.environ["HF_HOME"]),
    "raw_token_not_inherited": "HF_TOKEN" not in os.environ and "HUGGING_FACE_HUB_TOKEN" not in os.environ,
    "hub_library_uses_private_home": Path(constants.HF_HOME).resolve() == Path(os.environ["HF_HOME"]).resolve(),
    "hub_library_uses_private_token_path": Path(constants.HF_TOKEN_PATH).resolve() == Path(os.environ["HF_TOKEN_PATH"]).resolve(),
}
print(json.dumps({"checks": checks, "passed": all(checks.values())}))
sys.exit(0 if all(checks.values()) else 1)

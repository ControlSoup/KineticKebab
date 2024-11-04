import subprocess
import json
import os

KEBAB_PATH = os.path.join(
    os.path.dirname(__file__),
    '../zig-out/bin/kinetic_kebab'
)

class KebabCli:
    def __init__(self, file_path: str, kebab_path = KEBAB_PATH):

        with open(file_path, "r") as f:
            self.json = json.load(f)

        self.file_path = file_path
        self.kebab_path = kebab_path
    
    @property
    def raw_json(self):
        return json.dumps(self.json, indent=2)
    
    def update_recorder_options(self, path: str, pool_window: float = None):
        self.json["RecorderOptions"] = {}
        options = self.json["RecorderOptions"] 

        options["path"] = path
        
        if pool_window is not None:
            options["pool_window"] = pool_window
    
    def run(self, duration: float):
        try:
            os.remove(self.file_path)
        except OSError:
            pass
        
        with open(self.file_path, "w") as f:
            f.write(self.raw_json)

        
        subprocess.run(
            [self.kebab_path, "-d", str(duration), "-i", self.file_path]
        )
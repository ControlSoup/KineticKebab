import subprocess
import json
import os
import importlib.resources as ir

class KebabCli:
    def __init__(self, file_path: str, kebab_path = None):

        with open(file_path, "r") as f:
            self.json = json.load(f)

        self.file_path = file_path
        self.kebab_path = kebab_path
        self.native_execuable = ir.files('kinetic_kebab_api') / 'kinetic_kebab' 
    
    @property
    def raw_json(self):
        return json.dumps(self.json, indent=2)
       
    def update_sim_options(self, dt: float, max_dt: float = None, min_dt: float = None, allowable_error: float = None):
        self.json["SimOptions"] = {}
        options = self.json["SimOptions"]

        options["dt"] = dt

        if max_dt is not None:
            options["max_dt"] = max_dt

        if min_dt is not None:
            options["min_dt"] = min_dt 
            
        if allowable_error is not None:
            options["allowable_error"] = allowable_error  
    
    def update_recorder_options(self, path: str, min_dt: float = None, pool_window: float = None):
        self.json["RecorderOptions"] = {}
        options = self.json["RecorderOptions"] 

        options["path"] = path

        if min_dt is not None:
            options["min_dt"] = min_dt        

        if pool_window is not None:
            options["pool_window"] = pool_window
    
    def run(self, duration: float):
        try:
            os.remove(self.file_path)
        except OSError:
            pass
        
        with open(self.file_path, "w") as f:
            f.write(self.raw_json)

        if self.kebab_path is not None: 
            subprocess.run(
                [self.kebab_path, "-d", str(duration), "-i", self.file_path]
            )
        else:
            subprocess.run(
                [self.native_execuable, "-d", str(duration), "-i", self.file_path]
            )
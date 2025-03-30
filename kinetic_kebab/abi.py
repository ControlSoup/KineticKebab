from ctypes import *
import importlib.resources as ir
import numpy as np
from tqdm import tqdm
from copy import deepcopy


so = ir.files('kinetic_kebab') / 'libkinetic_kebab.so' 
lib = CDLL(so)

# Json to sim method
c_json_to_sim = lib.json_to_sim
c_json_to_sim.argtypes = [c_char_p, c_size_t]
c_json_to_sim.restype = c_void_p 

# Step Method
c_step = lib.step
c_step.argtypes = [c_void_p]
c_step.restype = None

# Step duration method
c_step_duration= lib.step_duration
c_step_duration.argtypes = [c_void_p, c_double]
c_step_duration.restype = None

# State names methods
class StateNames(Structure):
    _fields_ = [
        ("len", c_size_t),
        ("all_names", POINTER(POINTER(c_char))),
    ]

    def as_list(self):
        return [
            string_at(self.all_names[i]).decode("utf-8") for i in range(self.len)
        ]

c_state_names = lib.state_names
c_state_names.argtypes = [c_void_p]
c_state_names.restype = StateNames 

# State Values Methods
class StateVals(Structure):
    _fields_ = [("len", c_size_t), ("vals", POINTER(c_double))]

    def as_list(self):
        return [self.vals[i] for i in range(self.len)]

c_state_vals = lib.state_vals
c_state_vals.argtypes = [c_void_p]
c_state_vals.restype = StateVals 

# Set value by name
c_set_value_by_name = lib.set_value_by_name
c_set_value_by_name.argtypes = [c_void_p, c_char_p, c_size_t, c_double]
c_set_value_by_name.restype = None

# Get value by name
c_get_value_by_name = lib.get_value_by_name
c_get_value_by_name.argtypes = [c_void_p, c_void_p, c_size_t]
c_get_value_by_name.restype = c_double 

# Sim end
c_end = lib.end
c_end.argtypes = [c_void_p]
c_end.restype = None

# Steady Solve
c_solve_steady = lib.solve_steady
c_solve_steady.argtypes = [c_void_p]
c_solve_steady.restype = None 

# Iter Steady
c_iter_steady = lib.iter_steady
c_iter_steady.argtypes = [c_void_p]
c_iter_steady.restype = c_bool 

# Print Jacobian
c_print_jacobian = lib.print_jacobian
c_print_jacobian.argtypes = [c_void_p]
c_print_jacobian.restype = None

# Class Interface
class KineticKebab:
    def __init__(self, json_string: str):
        self.__json = json_string
        self.__sim_ptr = c_json_to_sim(self.__json.encode("utf-8"), len(self.__json))

        self.__state_names = deepcopy(c_state_names(self.__sim_ptr).as_list())

        self._history = []
        # self._save()
    
    def from_file(file_path: str) -> "KineticKebab":
        json_data = None
        with open(file_path) as f:
            json_data = f.read()

        return KineticKebab(json_data)

    @property
    def state_vals(self) -> list[float]:
        return deepcopy(c_state_vals(self.__sim_ptr).as_list())
    
    @property
    def state_names(self) -> list[str]:
        return self.__state_names

    @property
    def datadict(self) -> dict[str, np.array]:
        np_history = np.array(self._history)
        data = [np_history[:, i] for i in range(np_history.shape[1])]

        data_dict = {}
        for k,v in zip(self.state_names, data):
            data_dict[k] = v

        return data_dict

    def step(self) -> None:
        c_step(self.__sim_ptr)
        self._save()

    def step_duration(self, time: float) -> None:
        c_step_duration(self.__sim_ptr, time)
        self._save()

    def _save(self):
        self._history.append(self.state_vals)
    
    def end(self):
        self._history = []
        c_end(self.__sim_ptr)
    
    def run(self, duration: float, save_duration: float = 1e-3, show_progress = True):

        def progress(show_progess: bool):
            _range = range(int(duration / save_duration))

            if show_progess:
                return tqdm(_range)

            return _range 

        self._save()
        for i in progress(show_progress):
            self.step_duration(save_duration)

    def set_value_by_name(self, name: str, value: float) -> None:
        c_set_value_by_name(self.__sim_ptr, name.encode("utf-8"), len(name), value)

    def get_value_by_name(self, name: str) -> float:
        return c_get_value_by_name(self.__sim_ptr, name.encode("utf-8"), len(name))

    def iter_steady(self) -> bool:
        return c_iter_steady(self.__sim_ptr)

    def solve_steady(self) -> None:
        c_solve_steady(self.__sim_ptr)
        self._save()

    def debug_steady(self, itterations: int, print_jacobian: bool):
        for _ in range(int(itterations)):
            self.iter_steady()
            self._save()

            if (print_jacobian):
                c_print_jacobian(self.__sim_ptr)
        



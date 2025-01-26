from ctypes import *

lib = CDLL("./libkinetic_kebab.so")

json_to_sim = lib.json_to_sim
json_to_sim.argtypes = [c_char_p, c_size_t]
json_to_sim.restype = c_void_p 

step = lib.step
step.argtypes = [c_void_p]
step.restype = None

step_duration= lib.step_duration
step_duration.argtypes = [c_void_p, c_double]
step_duration.restype = None

get_value_by_name = lib.get_value_by_name
get_value_by_name.argtypes = [c_void_p, c_char_p, c_size_t]
get_value_by_name.restype = c_double 

class StateNames(Structure):
    _fields_ = [("len", c_size_t), ("vals", POINTER(POINTER(c_ubyte)))]

    def as_list(self):
        return [self.vals[i] for i in range(self.len)]

state_names = lib.state_names
state_names.argtypes = [c_void_p]
state_names.restype = StateNames 



class StateVals(Structure):
    _fields_ = [("len", c_size_t), ("vals", POINTER(c_double))]

    def as_list(self):
        return [self.vals[i] for i in range(self.len)]

state_vals = lib.state_vals
state_vals.argtypes = [c_void_p]
state_vals.restype = StateVals 



json = '''
{
    "SimOptions":{
        "dt": 0.50,
        "min_dt": 1e-5,
        "allowable_error": 1e-4
    },
    "SimObjects":[
        {
            "object": "fluids.volumes.Static",
            "name": "UpstreamTest",
            "press": 200000,
            "temp": 277,
            "volume": 10,
            "fluid": "Nitrogen",
            "connections_out": ["TestOrifice"]
        },
        {
            "object": "fluids.restrictions.Orifice",
            "name": "TestOrifice",
            "cda": 0.075,
            "mdot_method": "IdealCompressible"
        },
        {
            "object": "fluids.volumes.Void",
            "name": "DownstreamTest",
            "press": 100000,
            "temp": 277,
            "fluid": "Nitrogen",
            "connections_in": ["TestOrifice"]
        }
    ]
}
'''.encode("utf-8")

ptr = json_to_sim(json, len(json))
names = state_names(ptr)
print(names.len)
print([names.vals[i] for i in range(names.len)])
print(state_vals(ptr).as_list())
step(ptr)
print(state_vals(ptr).as_list())




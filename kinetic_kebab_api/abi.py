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



json = '''
{
    "SimOptions":{
        "dt": 0.50 
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


def get_state(state: str):
    utf8_state = state.encode("utf-8")
    print(f"{state}", get_value_by_name(ptr, utf8_state, len(state)))


get_state("UpstreamTest.press [Pa]")
get_state("sim.time [s]")
step_duration(ptr, 0.125)
get_state("UpstreamTest.press [Pa]")
get_state("sim.time [s]")


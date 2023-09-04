# ------------------------------------------------------------------------------ 
# Helper Functions for logging or printin
# ------------------------------------------------------------------------------ 
import numpy as np

def prett_str_key_val(*key_val_tuple, places = 3):
    '''
        Returns a string for logging or printing of a key value pair
    '''
    out_str = f''
    for tuple in key_val_tuple:
        out_str += f'[{tuple[1]}] = {np.round(tuple[2],places)}'
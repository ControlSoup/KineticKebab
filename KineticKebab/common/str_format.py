# ------------------------------------------------------------------------------ 
# Helper Functions for logging or printin
# ------------------------------------------------------------------------------ 
import numpy as np

SEP_START = '|'
SEP_END = '|'

TO = '\n    -->'
FROM = '\n    ^--'

FCN_TAG = '__'
CLASS_TAG = '--'


def pretty_fcn_name(title_string):
    return f'\n{FCN_TAG}{title_string}(){FCN_TAG}:\n'


def pretty_class_name(ClassName):
    return f'\n{CLASS_TAG}{ClassName}(){CLASS_TAG}:\n'


def pretty_str_key_val(*key_val_tuple, places = 3):
    '''
        Returns a string for logging or printing of a key value pair
    '''
    out_str = ''
    for tuple in key_val_tuple:
        out_str += f'{SEP_START}{tuple[0]}{SEP_END} = {np.round(tuple[1],places):,} \n\n'
    return out_str


def pretty_str_key_val_from_convert_val(*key_val_convert_val, places = 3):
    '''
        Returns a string for logging or printing of a key value pair that is converted FROM another key value pair
    '''
    out_str = f''
    for tuple in key_val_convert_val:
        out_str += f'{SEP_START}{tuple[0]}{SEP_END} = {np.round(tuple[1],places):,} {FROM} {SEP_START}{tuple[2]}{SEP_END} = {np.round(tuple[3],places):,}\n\n'
    return out_str


def pretty_str_key_val_to_convert_val(*key_val_convert_val, places = 3):
    '''
        Returns a string for logging or printing of a key value pair that is converted TO another key value pair
    '''
    out_str = f''
    for tuple in key_val_convert_val:
        out_str += f'{SEP_START}{tuple[0]}{SEP_END} = {np.round(tuple[1],places):,} {TO} {SEP_START}{tuple[2]}{SEP_END} = {np.round(tuple[3],places):,}\n\n'
    return out_str
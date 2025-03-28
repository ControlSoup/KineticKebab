const std = @import("std");

pub fn cv_from_base(sp_r: f64, gamma: f64) f64 {
    return sp_r / (gamma - 1.0);
}

pub fn cp_from_base(sp_r: f64, gamma: f64) f64 {
    return gamma * sp_r / (gamma - 1.0);
}

pub fn d_from_pt(sp_r: f64, press: f64, temp: f64) f64 {
    return press / (sp_r * temp);
}

pub fn u_from_t(cv: f64, temp1: f64, temp0: f64) f64 {
    return cv * (temp1 - temp0);
}

pub fn h_from_t(cp: f64, temp1: f64, temp0: f64) f64 {
    return cp * (temp1 - temp0);
}

pub fn s_from_pt(sp_r: f64, cp: f64, press1: f64, press0: f64, temp1: f64, temp0: f64) f64 {
    return cp * std.math.log(f64, std.math.e, temp1 / temp0) - (sp_r * std.math.log(f64, std.math.e, press1 / press0));
}

pub fn t_from_u(cv: f64, sp_inenergy: f64, temp0: f64) f64 {
    return (sp_inenergy + (cv * temp0)) / cv;
}

pub fn t_from_h(cp: f64, sp_inenergy: f64, temp0: f64) f64 {
    return (sp_inenergy + (cp * temp0)) / cp;
}

pub fn p_from_dt(sp_r: f64, density: f64, temp: f64) f64 {
    return density * sp_r * temp;
}

pub fn sos(gamma: f64, sp_r: f64, t: f64) f64 {
    return std.math.sqrt(gamma * sp_r * t);
}

/// Function that performs all required actions that are needed once per cycle
pub trait Update{
    fn update(&mut self);
}
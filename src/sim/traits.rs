/// Function that performs all required actions that are needed once per cycle
use std::{rc::Rc, cell::RefCell}

pub trait Update{
    fn update(&mut self, runtime: &mut super::Runtime);
}

pub fn update_all<U: Update>(mut objects: Vec<Rc<RefCell<U>>>, runtime: &mut super::Runtime){
    for i in objects.iter_mut(){
        let mut b = i.borrow_mut();
        b.update(runtime);
    }
}
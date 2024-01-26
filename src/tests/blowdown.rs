use crate::flow::FlowRestriction;

use super::*;

#[test]
fn blowdown(){
    let mut source = InfiniteVolume::new("100psia", 689476.0, 300.0, "nitrogen");
    let mut sink = InfiniteVolume::atm("ATM", "nitrogen");

    let source_rc_cell = Rc::from(RefCell::new(source));
    let sink_rc_cell = Rc::from(RefCell::new(sink));

    let mut orifice = RealOrifice::new(
        "Orifice",
        0.1,
        Rc::clone(&source_rc_cell),
        Rc::clone(&sink_rc_cell)
    );
    let orifice_rc_cell = Rc::from(RefCell::new(orifice));


    let mut all_objects: Vec<Rc<RefCell<dyn sim::Update>>> = Vec::new();
    all_objects.push(Rc::clone(&source_rc_cell) as Rc<RefCell<dyn sim::Update>>);
    all_objects.push(Rc::clone(&sink_rc_cell) as Rc<RefCell<dyn sim::Update>>);
    all_objects.push(Rc::clone(&orifice_rc_cell) as Rc<RefCell<dyn sim::Update>>);

    let mut runtime = sim::Runtime::new(10.0, 1e-3, "time [s]");

    while runtime.is_running(){
        sim::update_all(all_objects, &mut runtime);
        runtime.increment();
    }

}
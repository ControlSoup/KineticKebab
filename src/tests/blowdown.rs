use crate::flow::FlowRestriction;

use super::*;

#[test]
fn blowdown(){
    let mut source = InfiniteVolume::new("100psia", 689476.0, 300.0, "nitrogen");
    let mut sink = InfiniteVolume::atm("ATM", "nitrogen");


    let mut orifice = RealOrifice::new("Orifice", 0.1, Rc::from(source), Rc::from(sink));


    let mut all_objects: Vec<Rc<dyn sim::Update>> = Vec::new();
    all_objects.push(Rc::from(source));
    all_objects.push(Rc::from(sink));
    all_objects.push(Rc::from(orifice));


}
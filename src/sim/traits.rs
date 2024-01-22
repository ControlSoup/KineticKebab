/// Function that performs all required actions that are needed once per cycle
pub trait Update{
    fn update(&mut self, runtime: &mut super::Runtime);
}

fn update_all<U: Update>(objects: Vec<Box<U>>, runtime: &mut super::Runtime){
    for i in objects.iter(){
        i.update(runtime)
    }
}
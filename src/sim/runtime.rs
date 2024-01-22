use std::collections::{HashMap, BTreeMap};
use std::path::Path;
use csv;

#[allow(dead_code)]

#[derive(Debug)]
pub struct Runtime{
    x_key: String,
    x_increment: f64,
    x_array: Vec<f64>,
    current_index: usize,
    is_running: bool,
    data_dict: HashMap<String, Vec<f64>>
}

impl Runtime{
    pub fn new(
        max_x_value: f64,
        x_increment: f64,
        x_key: &str
    ) -> Runtime{

        // Intialize the array for which we will step through
        let x_key = x_key.to_string();
        let mut x_array: Vec<f64> = Vec::new();

        let mut current = 0.0;
        while current < max_x_value{
           current += x_increment;
           x_array.push(current);
        }

        // Remove mutability from the x_array
        let x_array = x_array;

        // Init Hashmap for Data Storage
        let data_dict: HashMap<String, Vec<f64>> = HashMap::new();

        return Runtime {
            x_key,
            x_increment,
            x_array,
            current_index: 0,
            is_running: true,
            data_dict
        }
    }

    pub fn add_or_set(&mut self, key: &str, value: f64) {

        if self.data_dict.contains_key(key){
            self.value_set(key, value);
        }

        else if self.current_index == 0{
            self.data_dict.insert(
                key.to_string(),
                vec![0.0; self.x_array.len()]
            );
            self.value_set(key, value);
        }

        else{
            panic!(
                "    ERROR| Dyanamic key [{}] must be intialized \
                befor incrementing the runtime. \n
                           Index is currently [{}]",
                key,
                self.current_index + 1
            )
        }
    }

    pub fn increment(&mut self){

        if self.current_index < (self.x_array.len() - 1){
            self.current_index += 1;

            // Store the current value
            for (_, array) in self.data_dict.iter_mut(){
                array[self.current_index] = array[self.current_index - 1];
            }
        } else {
            self.is_running = false;
        };

    }

    pub fn value_set(&mut self, key: &str, value: f64){
        // Write the current value
        if let Some(array) = self.data_dict.get_mut(key){
            array[self.current_index] = value;
        } else{
            panic!("    ERROR| Get Value Key [{}] not in data_dict", key)
        }
    }

    pub fn get_value(&self, key: &str) -> f64{
        // Read the current value
        if let Some(array) = self.data_dict.get(key){
            return array[self.current_index];
        } else{
            panic!("    ERROR| Get Value Key [{}] not in data_dict", key)
        }
    }

    pub fn get_curr_index(&self) -> usize{
        return self.current_index
    }

    pub fn get_x(&self) -> f64{
        return self.x_array[self.current_index];
    }

    pub fn get_dx(&self) -> f64{
        return self.x_increment;
    }

    pub fn get_max_x(&self) -> f64{
        return self.x_array[(self.x_array.len() - 1)..][0]
    }

    pub fn is_running(&self) -> bool{
        return self.is_running
    }

    fn trim_from_curr_index(&mut self){

        let mut  new_hashmap: HashMap<String, Vec<f64>> = HashMap::new();
        for (key, array) in self.data_dict.iter_mut(){
            let sub_array = &array[..self.current_index + 1];
            new_hashmap.insert(key.clone(), sub_array.to_owned());
        }

        // X array
        let new_x_array = &self.x_array[..self.current_index + 1];

        self.x_array = new_x_array.to_vec();

        // Replace the hasmap
        self.data_dict = new_hashmap;
    }

    pub fn export_to_csv(&mut self, file_path: &str){
        let path = Path::new(file_path);

        // Attempt to write to this path and overwrite
        let mut writer = match csv::Writer::from_path(path){
            Ok(file) => file,
            Err(err) => {
                panic!(
                    "ERROR| Could not export to path {}: {}",
                    path.to_string_lossy(),
                    err
                );
            }
        };

        // Trim the data
        self.trim_from_curr_index();

        // Sort Alphabetically
        let sorted_datadict: BTreeMap<String, Vec<f64>> = self.data_dict
            .clone()
            .into_iter()
            .collect();

        // Header
        let mut header: Vec<&str> = sorted_datadict
            .keys()
            .map(|s| s.as_str())
            .collect();

        header.push(self.x_key.as_str());

        writer.write_record(&header).unwrap();

        // Body
        for (i, &time) in self.x_array.iter().enumerate(){

            let mut data_row: Vec<String> = Vec::new();
            for &key in header.iter(){
                if key != self.x_key{
                    let value = sorted_datadict.get(key).unwrap();
                    let value = value[i];
                    data_row.push(
                        value.to_string()
                    );
                } else{
                    data_row.push(
                        time.to_string()
                    );
                }
            }

            // Convert to a &str for writing
            let data_row_str: Vec<&str> = data_row.iter().map(|s| s.as_str()).collect();
            writer.write_record(data_row_str).unwrap();
        }
        writer.flush().unwrap();
    }

}
pub trait Save{
    fn save_data(&self, prefix: &str, runtime: &mut Runtime) where Self: Sized;

    fn save_data_verbose(&self, prefix: &str, runtime: &mut Runtime) where Self: Sized{
        // Allow one call for verbose and non verbose data
        self.save_data(prefix, runtime);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn basic_test() {

        let dynamic_key = "test_count [-]";

        // Intialize a RunTime
        let mut runtime =  Runtime::new(
            10.0,
            1.0,
            "time [s]"
        );

        runtime.add_or_set(dynamic_key, 10.0);
        assert_eq!(runtime.get_curr_index(), 0);
        assert_eq!(runtime.get_value(dynamic_key), 10.0);

        // Test a single incrementation
        runtime.increment();
        assert_eq!(runtime.get_curr_index(), 1);

        runtime.add_or_set(
            dynamic_key,
            runtime.get_value(dynamic_key) - 1.0
        );

        assert_eq!(runtime.get_value(dynamic_key), 9.0);

        for _ in 1..5{
            runtime.increment();

            runtime.add_or_set(
                dynamic_key,
                runtime.get_value(dynamic_key) - 1.0
            );
        }

        // runtime.export_to_csv("test", "")

    }
}
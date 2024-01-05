use std::ops::{Mul, Div, Add};


pub trait Integrate{

    fn effects(&mut self){()}

    fn get_derivative(&self)-> Self;

    fn rk4(&mut self, dt: f64) -> Self
        where Self:
            Sized +
            Clone +
            Add<Self, Output = Self> +
            Mul<f64, Output = Self> +
            Div<f64, Output = Self>,
    {
        self.effects();

        let k1 = self.get_derivative();
        let k2 = (self.clone() + (k1.clone() * dt / 2.0)).get_derivative();
        let k3 = (self.clone() + (k2.clone() * dt / 2.0)).get_derivative();
        let k4 = (self.clone() + k3.clone() * dt).get_derivative();

        return self.clone() + ((k1 + (k2 * 2.0) + (k3 * 2.0) + k4) * dt / 6.0)
    }

    fn euler(&mut self, dt: f64)-> Self
        where
            Self:
                Sized +
                Clone +
                Add<Self, Output = Self> +
                Mul<f64, Output = Self>
    {
        self.effects();

        let euler =  self.clone() + (self.get_derivative() * dt);
        return euler
    }
}

#[cfg(test)]
mod tests {

    use super::*;
    use approx::assert_relative_eq;
    #[derive(
        Debug,
        Clone,
        Copy,
        PartialEq,
        derive_more::Add,
        derive_more::Sub,
        derive_more::Mul,
        derive_more::Div,
        derive_more::Neg
    )]

    struct Location{
        force: f64,
        mass: f64,
        position: f64,
        velocity: f64,
        acceleration: f64,
    }

    impl Location{
        fn init() -> Location{
            return Location{
                force: 1.0,
                mass: 1.0,
                position: 0.0,
                velocity: 0.0,
                acceleration: 0.0
            }
        }

        fn zeros() -> Location{
            return Location {
                force: 0.0,
                mass: 0.0,
                position: 0.0,
                velocity: 0.0,
                acceleration: 0.0
            }
        }
    }

    impl Integrate for Location{

        fn effects(&mut self) {
            self.acceleration = self.force / self.mass;
        }

        fn get_derivative(&self)-> Self {
            let mut derivative = Location::zeros();
            derivative.velocity = self.acceleration;
            derivative.position = self.velocity;

            return derivative
        }
    }


    #[test]
    fn euler(){

        let mut test_vehicle = Location::init();

        let time: f64 = 10.0;
        let dt: f64 = 1e-6;
        let closest_int: i64 = (time / dt) as i64;

        for _ in 0..closest_int{
            test_vehicle = test_vehicle.euler(dt);
        }

        // vf = vi + (f/m)t = [10.0]
        assert_relative_eq!(
            test_vehicle.velocity,
            10.0,
            max_relative = 1.0e-6
        );

        // x = vi * t + a * t^2 /2  = [50.0]
        assert_relative_eq!(
            test_vehicle.position,
            50.0,
            max_relative = 1.0e-6
        );

    }

    #[test]
    fn rk4(){

        let mut test_vehicle = Location::init();

        let time: f64 = 10.0;
        let dt: f64 = 5.0;
        let closest_int: i64 = (time / dt) as i64;

        for _ in 0..closest_int{
            test_vehicle = test_vehicle.rk4(dt);
        }

        // vf = vi + (f/m)t = [10.0]
        assert_relative_eq!(
            test_vehicle.velocity,
            10.0,
            max_relative = 1.0e-6
        );

        // x = vi * t + a * t^2 /2  = [50.0]
        assert_relative_eq!(
            test_vehicle.position,
            50.0,
            max_relative = 1.0e-6
        );

    }
}
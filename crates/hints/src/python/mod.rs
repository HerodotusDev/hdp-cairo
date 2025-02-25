use std::{borrow::Cow, env};

use cairo_vm::Felt252;
use pyo3::prelude::*;
pub mod garaga;

pub fn initialize_python() -> PyResult<()> {
    // Set PYTHONPATH to include your project's Python modules
    let current_path = env::current_dir()?;
    let python_path = format!(
        "{}:{}",
        current_path.join("packages").display(),
        env::var("PYTHONPATH").unwrap_or_default()
    );
    env::set_var("PYTHONPATH", python_path);

    Ok(())
}

use std::{collections::HashMap, env, ops::Mul};

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_address_from_var_name, get_integer_from_var_name, get_ptr_from_var_name, get_relocatable_from_var_name},
    },
    types::{exec_scope::ExecutionScopes, relocatable::Relocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use pyo3::{
    prelude::*,
    types::{PyDict, PyInt, PyList, PyLong},
};
use types::cairo::traits::CairoType;

use super::types::UInt384;
use crate::python::garaga::types::ModuloCircuit;
pub struct ModCircuitResult {
    pub witnesses: Vec<u64>,
    // Add other fields as needed
}
pub const MODULO_CIRCUIT_IMPORTS: &str = r#"from precompiled_circuits.all_circuits import ALL_FUSTAT_CIRCUITS, CircuitID, find_best_circuit_id_from_int
from garaga.hints.io import pack_bigint_ptr, fill_felt_ptr, flatten, bigint_split
from garaga.definitions import CURVES, PyFelt"#;

pub fn modulo_circuit_imports(
    _vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    Ok(())
}

pub const RUN_MODULO_CIRCUIT: &str = r#"circuit_input = pack_bigint_ptr(memory, ids.input, ids.N_LIMBS, ids.BASE, ids.circuit.input_len//ids.N_LIMBS)
# Convert the int value back to a string and print it
circuit_name = ids.circuit.name.to_bytes((ids.circuit.name.bit_length() + 7) // 8, 'big').decode()
#print(f"circuit.name = {circuit_name}")
circuit_id = find_best_circuit_id_from_int(ids.circuit.name)
# print(f"best_match = {circuit_id.name}")
MOD_CIRCUIT = ALL_FUSTAT_CIRCUITS[circuit_id]['class'](ids.circuit.curve_id, auto_run=False)
MOD_CIRCUIT = MOD_CIRCUIT.run_circuit(circuit_input)
witnesses = flatten([bigint_split(x.value, ids.N_LIMBS, ids.BASE) for x in MOD_CIRCUIT.witnesses])
fill_felt_ptr(x=witnesses, memory=memory, address=ids.range_check96_ptr + ids.circuit.constants_ptr_len * ids.N_LIMBS + ids.circuit.input_len)
#MOD_CIRCUIT.print_value_segment()"#;

/// Packs multiple limbs into a single value using the formula: sum(limb[i] * base^i)
fn bigint_pack_ptr(vm: &VirtualMachine, ptr: Relocatable) -> Result<UInt384, HintError> {
    Ok(UInt384::from_memory(vm, ptr)?)
}

/// Packs multiple groups of limbs into a vector of values
/// Each group consists of n_limbs consecutive values that are packed using bigint_pack_ptr
fn pack_bigint_ptr_vec(vm: &VirtualMachine, ptr: Relocatable, n_limbs: u32, n_elements: usize) -> Result<Vec<UInt384>, HintError> {
    let mut values = Vec::with_capacity(n_elements);

    for i in 0..n_elements {
        let offset = (i * n_limbs as usize) as u32;
        let element_ptr = (ptr + offset).unwrap();
        values.push(bigint_pack_ptr(vm, element_ptr)?);
    }

    Ok(values)
}

pub fn run_modulo_circuit(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    println!("Running modulo circuit");

    // Python::with_gil(|py| {
    //     // Import IsogenyG1 from garaga
    //     let isogeny_module = py.import("garaga.precompiled_circuits.isogeny").unwrap();
    //     let isogeny_g1 = isogeny_module.getattr("IsogenyG1").unwrap();
        
    //     // Initialize circuit with BLS12-381 curve (curve_id = 1)
    //     let circuit = isogeny_g1.call1(("isogeny", 1)).unwrap();
        
    //     // Get the curve property
    //     let curve = circuit.getattr("curve").unwrap();
        
    //     println!("Curve properties:");
    //     println!("ID: {}", curve.getattr("id").unwrap());
    //     println!("a parameter: {}", curve.getattr("a").unwrap());
    //     println!("b parameter: {}", curve.getattr("b").unwrap());
    //     println!("Field characteristic p: {}", curve.getattr("p").unwrap());
    //     println!("Generator x coordinate: {}", curve.getattr("Gx").unwrap());
    //     println!("Generator y coordinate: {}", curve.getattr("Gy").unwrap());
        
    
    // });

    // Python::with_gil(|py| {
    //     // Get the current directory and construct path to packages
    //     let current_dir = env::current_dir().unwrap();
    //     let packages_path = current_dir.join("packages").join("garaga_zero").to_string_lossy().into_owned();
        
    //     // Add the packages directory to Python path
    //     let sys = py.import("sys").unwrap();
    //     let path = sys.getattr("path").unwrap();
    //     path.call_method1("append", (packages_path,)).unwrap();
        
    //     // Import the module
    //     let module_path = "precompiled_circuits.all_circuits";
    //     let garaga_module = py.import(module_path).unwrap();
        
    //     let find_circuit = garaga_module.getattr("find_best_circuit_id_from_int").unwrap();
    //     let result = find_circuit.call1((1,)).unwrap();
        
    //     println!("Result: {:?}", result);
        
    //     // Ok(())
    // });
        
    // Convert VM memory to HashMap

    // Extract parameters from ids
    // let result = compute_mod_circuit(
    //     vm,
    //     ids.get("circuit.name").unwrap().to_string(),
    //     ids.get("circuit.curve_id").unwrap().to_integer() as u32,
    //     vec![ids.get("input").unwrap() as u64],
    //     ids.get("N_LIMBS").unwrap().to_integer() as u32,
    //     ids.get("BASE").unwrap().to_integer() as u64,
    //     ids.get("circuit.input_len").unwrap().to_integer() as usize,
    // ).map_err(|e| HintError::CustomHint(format!("Python error: {}", e)))?;

    let res = compute_mod_circuit(vm, exec_scopes, _hint_data, _constants).unwrap();

    // // Write witnesses back to VM memory
    // let address = ids.get("range_check96_ptr").unwrap().to_integer()
    //     + ids.get("circuit.constants_ptr_len").unwrap().to_integer() * ids.get("N_LIMBS").unwrap().to_integer()
    //     + ids.get("circuit.input_len").unwrap().to_integer();

    // for (i, witness) in result.witnesses.iter().enumerate() {
    //     vm.insert_value(
    //         (address + i as u64).into(),
    //         Felt252::from(*witness),
    //     )?;
    // }

    Ok(())
}

pub fn compute_mod_circuit(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> PyResult<ModCircuitResult> {
    let input_ptr = get_ptr_from_var_name("input", vm, &hint_data.ids_data, &hint_data.ap_tracking).unwrap();
    let n_limbs: u32 = constants["definitions.N_LIMBS"].try_into().unwrap();
    let circuit_address = get_ptr_from_var_name("circuit", vm, &hint_data.ids_data, &hint_data.ap_tracking).unwrap();
    let circuit = ModuloCircuit::from_memory(vm, circuit_address).unwrap();
    let input_len: u32 = circuit.input_len.try_into().unwrap();
    let base: u128 = constants["definitions.BASE"].try_into().unwrap();

    let circuit_input = pack_bigint_ptr_vec(vm, input_ptr, n_limbs, input_len as usize / n_limbs as usize).unwrap();

    let curve_id: u64 = circuit.curve_id.try_into().unwrap();

    Python::with_gil(|py| {
        let current_dir = env::current_dir()?;
        let packages_path = current_dir.join("packages").join("garaga_zero").to_string_lossy().into_owned();
        
        
        let algebra = py.import("garaga.algebra")?;
        let curves = py.import("garaga.definitions")?;
        
        // Add the packages directory to Python path
        let sys = py.import("sys")?;
        let path = sys.getattr("path")?;
        path.call_method1("append", (packages_path,))?;
        
        // Import the module
        // let module_path = "precompiled_circuits.all_circuits";
        let all_circuits = py.import("precompiled_circuits.all_circuits")?;

        // Convert circuit name to string
        let circuit_name = circuit.name.to_string();
        let py_circuit_name = Python::with_gil(|py| {
            // Create a Python int from the decimal string
            py.eval(&format!("int('{}')", circuit_name), None, None)?
                .extract::<PyObject>()
        })?;

        let find_circuit = all_circuits.getattr("find_best_circuit_id_from_int")?;
        let circuit_id = find_circuit.call1((py_circuit_name,))?;
        println!("circuit_id: {:?}", circuit_id);

        // Get circuit class from ALL_FUSTAT_CIRCUITS
        let all_circuits = all_circuits.getattr("ALL_FUSTAT_CIRCUITS")?;
        let circuit_info = all_circuits.get_item(circuit_id)?;
        let circuit_class = circuit_info.get_item("class")?;
        println!("got circuit class");
        // // Convert Felt252 to u64 for Python
        let curve_id_int: u64 = circuit.curve_id.to_bigint().try_into().unwrap();
        println!("got curve_id_int");
        // // Create circuit instance with converted curve_id
        let mod_circuit = circuit_class.call1((curve_id_int, false))?;
        println!("got mod_circuit");

        let curves_dict = curves.getattr("CURVES")?;
        let py_felt_class = algebra.getattr("PyFelt")?;
        let curve = curves_dict.get_item(curve_id)?;
        let p = curve.getattr("p")?;
        println!("p: {:?}", p);
        // // Convert circuit_input to Python list
        let py_input = circuit_input.iter().map(|uint384| -> PyResult<PyObject> {
            let bytes = uint384.to_bytes();            
            let py_int = py.eval(
                &format!("int.from_bytes({:?}, 'big')", bytes),
                None,
                None
            )?;

            Ok(py_int.into())
        }).collect::<PyResult<Vec<_>>>()?; // Handle the Result from collect

        let mod_circuit = mod_circuit.call_method1("run_circuit", (py_input,))?;
        let witnesses = mod_circuit.getattr("witnesses")?;
        println!("got witnesses: {:?}", witnesses);
        // let mut witness_values = Vec::new();

        // Extract witness values and convert them
        for witness in witnesses.iter()? {
            let witness = witness?;
            let value = witness.getattr("value")?;

            // Convert each limb using bigint_split
            // let limbs = garaga_hints.getattr("bigint_split")?.call1((value, n_limbs, base))?;
            println!("value: {:?}", value);

            // // Flatten the limbs into our witness values
            // for limb in limbs.iter()? {
            //     let limb_value: u64 = limb?.extract()?;
            //     witness_values.push(limb_value);
            // }
        }

        Ok(ModCircuitResult { witnesses: vec![] })
    })
}

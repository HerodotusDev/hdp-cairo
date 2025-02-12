#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![forbid(unsafe_code)]

use std::{env, str::FromStr};

use cairo_vm::{
    cairo_run::{self, cairo_run_program},
    types::{layout_name::LayoutName, program::Program},
    vm::runners::cairo_pie::CairoPie, Felt252,
};
use sound_hint_processor::CustomHintProcessor;
use types::{error::Error, HDPInput};

pub const HDP_COMPILED_JSON: &str = env!("HDP_COMPILED_JSON");
pub const HDP_PROGRAM_HASH: &str = env!("HDP_PROGRAM_HASH");

pub fn exec(input: HDPInput) -> Result<(CairoPie, Vec<Felt252>), Error> {
    let cairo_run_config = cairo_run::CairoRunConfig {
        layout: LayoutName::starknet_with_keccak,
        secure_run: Some(true),
        allow_missing_builtins: Some(false),
        ..Default::default()
    };

    let program_file = std::fs::read(HDP_COMPILED_JSON).map_err(Error::IO)?;
    let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint))?;

    let mut hint_processor = CustomHintProcessor::new(input);
    let mut cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor)?;

    let pie = cairo_runner.get_cairo_pie().map_err(|e| Error::CairoPie(e.to_string()))?;

    let mut output_buffer = String::new();
    cairo_runner.vm.write_output(&mut output_buffer)?;
    
    // Parse the output into separate lines, skipping the "Program Output:" header
    let outputs: Vec<Felt252> = output_buffer
        .lines()
        .map(|s| Felt252::from_str(s).unwrap())
        .collect();

    Ok((pie, outputs))
}
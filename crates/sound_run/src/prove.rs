use std::collections::HashMap;

use cairo_vm::vm::runners::cairo_runner::CairoRunner;
use stwo_cairo_adapter::{
    builtins::MemorySegmentAddresses,
    memory::{MemoryBuilder, MemoryConfig, MemoryEntry},
    vm_import::{adapt_to_stwo_input, RelocatedTraceEntry},
    ProverInput, PublicSegmentContext,
};
use tracing::{debug, info};

/// Extracts artifacts from a finished cairo runner, to later be used for proving.
pub fn prover_input_from_runner(runner: &CairoRunner) -> ProverInput {
    let public_input = runner.get_air_public_input().unwrap();
    let addresses = public_input
        .public_memory
        .iter()
        .map(|entry| entry.address as u32)
        .collect::<Vec<_>>();
    let segments = public_input
        .memory_segments
        .iter()
        .map(|(&k, v)| {
            (
                k,
                MemorySegmentAddresses {
                    begin_addr: v.begin_addr,
                    stop_ptr: v.stop_ptr,
                },
            )
        })
        .collect::<HashMap<_, _>>();
    let trace = runner
        .relocated_trace
        .as_ref()
        .unwrap()
        .iter()
        .map(|x| RelocatedTraceEntry {
            ap: x.ap,
            fp: x.fp,
            pc: x.pc,
        })
        .collect::<Vec<_>>();
    let mem = runner.relocated_memory.iter().enumerate().filter_map(|(i, x)| {
        x.as_ref().map(|value| MemoryEntry {
            address: i as u64,
            value: bytemuck::cast(value.to_bytes_le()),
        })
    });
    let mem = MemoryBuilder::from_iter(MemoryConfig::default(), mem);
    let main_args = runner.get_program().iter_builtins().copied().collect::<Vec<_>>();
    let public_segment_context = PublicSegmentContext::new(&main_args);

    info!("Generating input for the prover...");
    let input = adapt_to_stwo_input(&trace, mem, addresses, &segments, public_segment_context).unwrap();
    info!("Input for the prover generated successfully.");
    debug!("State transitions: {}", input.state_transitions.casm_states_by_opcode);
    debug!("Builtins: {:#?}", input.builtins_segments.get_counts());
    input
}

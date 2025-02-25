use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine};

pub fn print_address_range(vm: &VirtualMachine, address: Relocatable, depth: usize, padding: Option<usize>) {
    let padding = padding.unwrap_or(0); // Default to 20 if not specified
    let start_offset = if address.offset >= padding { address.offset - padding } else { 0 };
    let end_offset = address.offset + depth + padding;

    println!("\nFull memory segment range for segment {}:", address.segment_index);
    println!("----------------------------------------");
    for i in start_offset..end_offset {
        let addr = Relocatable {
            segment_index: address.segment_index,
            offset: i,
        };
        match vm.get_maybe(&addr) {
            Some(value) => println!("Offset {}: {:?}", i, value),
            None => println!("Offset {}: <empty>", i),
        }
    }
    println!("----------------------------------------\n");
}

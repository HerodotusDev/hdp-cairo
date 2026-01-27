use std::path::PathBuf;

use cairo_vm::Felt252;
use serde_json::Value;

use crate::error::Error;

/// Deserialize and pretty print output preimage using ABI from contract class
pub fn print_output_preimage(
    preimage_path: &PathBuf,
    compiled_module_path: &PathBuf,
) -> Result<(), Error> {
    print_output_preimage_with_options(preimage_path, compiled_module_path, false)
}

/// Deserialize and pretty print output preimage using ABI from contract class
/// with options to control formatting
pub fn print_output_preimage_with_options(
    preimage_path: &PathBuf,
    compiled_module_path: &PathBuf,
    show_struct_names: bool,
) -> Result<(), Error> {
    println!("\nOutput Preimage (deserialized via ABI):");
    println!("{}", "=".repeat(80));

    // Read the preimage file
    let preimage_data: Vec<Felt252> = if preimage_path.exists() {
        let file_content = std::fs::read(preimage_path).map_err(|e| {
            Error::IO(std::io::Error::new(
                std::io::ErrorKind::Other,
                format!(
                    "Failed to read output preimage file {}: {}",
                    preimage_path.display(),
                    e
                ),
            ))
        })?;

        serde_json::from_slice(&file_content).map_err(|e| {
            Error::IO(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                format!("Failed to deserialize output preimage JSON: {}", e),
            ))
        })?
    } else {
        println!(
            "  Warning: Output preimage file not found at {}",
            preimage_path.display()
        );
        return Ok(());
    };

    if preimage_data.is_empty() {
        println!("  (empty)");
        return Ok(());
    }

    // Try to get ABI from contract class file
    let (abi_output_type, full_abi) = get_abi_output_type(compiled_module_path)?;

    // Deserialize based on ABI
    if let Some(output_type) = abi_output_type {
        deserialize_with_abi_full(&preimage_data, &output_type, full_abi.as_ref(), show_struct_names)?;
    } else {
        // Fallback to basic pretty printing if ABI not found
        println!("  Warning: Could not find output type in ABI, using basic format");
        print_basic_format(&preimage_data);
    }

    println!();
    println!("{}", "=".repeat(80));
    println!();

    Ok(())
}

fn get_abi_output_type(compiled_module_path: &PathBuf) -> Result<(Option<Value>, Option<Value>), Error> {
    // Convert compiled_module path to contract_class path
    // e.g., example.compiled_contract_class.json -> example.contract_class.json
    let contract_class_path = compiled_module_path
        .to_string_lossy()
        .replace(".compiled_contract_class.json", ".contract_class.json")
        .replace("compiled_contract_class.json", "contract_class.json");

    let contract_class_path = PathBuf::from(contract_class_path);

    if !contract_class_path.exists() {
        return Ok((None, None));
    }

    let contract_class_content = std::fs::read(&contract_class_path).map_err(|e| {
        Error::IO(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!(
                "Failed to read contract class file {}: {}",
                contract_class_path.display(),
                e
            ),
        ))
    })?;

    let contract_class: Value = serde_json::from_slice(&contract_class_content).map_err(|e| {
        Error::IO(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            format!("Failed to parse contract class JSON: {}", e),
        ))
    })?;

    // Find the main function or any function with outputs
    let abi = match contract_class.get("abi").and_then(|v| v.as_array()) {
        Some(abi) => abi,
        None => return Ok((None, None)),
    };

    let full_abi = Value::Array(abi.clone());

    // Look for main function first, then any function with outputs
    let function = abi
        .iter()
        .find(|item| {
            item.get("type") == Some(&Value::String("function".to_string()))
                && item.get("name") == Some(&Value::String("main".to_string()))
        })
        .or_else(|| {
            abi.iter().find(|item| {
                item.get("type") == Some(&Value::String("function".to_string()))
                    && item.get("outputs").is_some()
            })
        });

    if let Some(func) = function {
        if let Some(outputs) = func.get("outputs") {
            return Ok((Some(outputs.clone()), Some(full_abi)));
        }
    }

    Ok((None, Some(full_abi)))
}

fn deserialize_with_abi_full(
    preimage_data: &[Felt252],
    output_type: &Value,
    full_abi: Option<&Value>,
    show_struct_names: bool,
) -> Result<(), Error> {
    // Get the contract class to find struct definitions
    // We need to get the full ABI to resolve struct types
    if let Some(outputs_array) = output_type.as_array() {
        if outputs_array.len() == 1 {
            let output = &outputs_array[0];
            if let Some(type_str) = output.get("type").and_then(|v| v.as_str()) {
                // Try to deserialize based on type
                let mut offset = 0;
                match deserialize_type(preimage_data, &mut offset, type_str, full_abi) {
                    Ok(deserialized) => {
                        // Extract struct name from type string (e.g., "example_rsi::module::SpinResult" -> "SpinResult")
                        let struct_name = type_str
                            .split("::")
                            .last()
                            .unwrap_or(type_str)
                            .to_string();
                        
                        // Print with custom formatter that preserves order and adds bold formatting
                        print_formatted_struct(&struct_name, &deserialized, full_abi, 0, show_struct_names)?;
                        return Ok(());
                    }
                    Err(e) => {
                        println!("  Warning: Failed to deserialize with ABI: {}", e);
                        println!("  Falling back to basic format");
                    }
                }
            }
        }
    }

    // Fallback to basic format
    println!("  Output Type: (unknown or complex)");
    print_basic_format(preimage_data);
    Ok(())
}

// Helper function to find struct in ABI by name (handles both full and short names)
fn find_struct_in_abi<'a>(abi: Option<&'a Value>, struct_name: &str) -> Option<&'a Value> {
    if let Some(abi_val) = abi {
        if let Some(abi_array) = abi_val.as_array() {
            // Try exact match first
            if let Some(struct_def) = abi_array.iter().find(|item| {
                item.get("type") == Some(&Value::String("struct".to_string()))
                    && item.get("name") == Some(&Value::String(struct_name.to_string()))
            }) {
                return Some(struct_def);
            }
            // Try matching by suffix (e.g., "module::FulfillmentCheckResult" matches "FulfillmentCheckResult")
            if let Some(struct_def) = abi_array.iter().find(|item| {
                if item.get("type") == Some(&Value::String("struct".to_string())) {
                    if let Some(name) = item.get("name").and_then(|v| v.as_str()) {
                        return name == struct_name || name.ends_with(&format!("::{}", struct_name));
                    }
                }
                false
            }) {
                return Some(struct_def);
            }
        }
    }
    None
}

fn deserialize_type(
    data: &[Felt252],
    offset: &mut usize,
    type_str: &str,
    abi: Option<&Value>,
) -> Result<Value, Error> {
    if *offset >= data.len() {
        return Err(Error::IO(std::io::Error::new(
            std::io::ErrorKind::UnexpectedEof,
            "Unexpected end of data",
        )));
    }

    // Handle basic types
    if type_str == "core::felt252" {
        let value = data[*offset];
        *offset += 1;
        return Ok(Value::String(format!("0x{:x}", value)));
    }

    if type_str == "core::bool" || type_str == "bool" {
        let value = data[*offset];
        *offset += 1;
        let bool_val = value != Felt252::ZERO;
        return Ok(Value::Bool(bool_val));
    }

    // Handle integer types (u8, u16, u32, u64, u128) - all stored as single felt252
    if type_str == "core::integer::u8" || type_str == "u8" {
        let value = data[*offset];
        *offset += 1;
        let bytes = value.to_bytes_be();
        let u8_val = bytes[31];
        return Ok(Value::Number(u8_val.into()));
    }

    if type_str == "core::integer::u16" || type_str == "u16" {
        let value = data[*offset];
        *offset += 1;
        let bytes = value.to_bytes_be();
        let u16_val = u16::from_be_bytes([bytes[30], bytes[31]]);
        return Ok(Value::Number(u16_val.into()));
    }

    if type_str == "core::integer::u32" || type_str == "u32" {
        let value = data[*offset];
        *offset += 1;
        let bytes = value.to_bytes_be();
        let u32_val = u32::from_be_bytes([bytes[28], bytes[29], bytes[30], bytes[31]]);
        return Ok(Value::Number(u32_val.into()));
    }

    if type_str == "core::integer::u64" || type_str == "u64" {
        let value = data[*offset];
        *offset += 1;
        let bytes = value.to_bytes_be();
        let u64_val = u64::from_be_bytes([
            bytes[24], bytes[25], bytes[26], bytes[27], bytes[28], bytes[29], bytes[30], bytes[31],
        ]);
        return Ok(Value::Number(u64_val.into()));
    }

    if type_str == "core::integer::u128" || type_str == "u128" {
        let value = data[*offset];
        *offset += 1;
        let bytes = value.to_bytes_be();
        let u128_val = u128::from_be_bytes([
            bytes[16], bytes[17], bytes[18], bytes[19], bytes[20], bytes[21], bytes[22], bytes[23],
            bytes[24], bytes[25], bytes[26], bytes[27], bytes[28], bytes[29], bytes[30], bytes[31],
        ]);
        return Ok(Value::String(format!("{}", u128_val)));
    }

    // Handle u256 (two felt252: low, high)
    if type_str == "core::integer::u256" || type_str == "u256" {
        if *offset + 1 >= data.len() {
            return Err(Error::IO(std::io::Error::new(
                std::io::ErrorKind::UnexpectedEof,
                "Not enough data for u256",
            )));
        }
        let low = data[*offset];
        let high = data[*offset + 1];
        *offset += 2;
        
        // Convert to hex string (high * 2^128 + low)
        let u256_str = if high == Felt252::ZERO {
            format!("0x{:x}", low)
        } else {
            format!("0x{:x}{:032x}", high, low)
        };
        return Ok(Value::String(u256_str));
    }

    // Handle fixed-size arrays: [T; N] -> just elements (no length prefix)
    if let Some(rest) = type_str.strip_prefix('[').and_then(|s| s.strip_suffix(']')) {
        if let Some((inner_type, size_str)) = rest.split_once("; ") {
            if let Ok(size) = size_str.trim().parse::<usize>() {
                // Fixed-size array - deserialize N elements
                let mut elements = Vec::new();
                for _ in 0..size {
                    elements.push(deserialize_type(data, offset, inner_type.trim(), abi)?);
                }
                return Ok(Value::Array(elements));
            }
        }
    }

    // Handle dynamic arrays: Array<T> -> length (felt252) + elements
    if let Some(inner_type) = type_str.strip_prefix("core::array::Array::<").and_then(|s| s.strip_suffix(">")) {
        // Get length - felt252 stores length, extract as usize
        let len_felt = data[*offset];
        let len_val = {
            let bytes = len_felt.to_bytes_be();
            // Extract last 8 bytes as u64 (big-endian)
            let mut buf = [0u8; 8];
            buf.copy_from_slice(&bytes[24..32]);
            u64::from_be_bytes(buf) as usize
        };
        *offset += 1;

        // Deserialize elements
        let mut elements = Vec::new();
        for _ in 0..len_val {
            elements.push(deserialize_type(data, offset, inner_type, abi)?);
        }
        return Ok(Value::Array(elements));
    }

    // Handle enums - serialized as variant index (felt252)
    if let Some(abi_val) = abi {
        if let Some(abi_array) = abi_val.as_array() {
            // Try to find enum definition
            if let Some(enum_def) = abi_array.iter().find(|item| {
                item.get("type") == Some(&Value::String("enum".to_string()))
                    && (item.get("name") == Some(&Value::String(type_str.to_string()))
                        || item.get("name").and_then(|v| v.as_str()).map_or(false, |n| {
                            n == type_str || n.ends_with(&format!("::{}", type_str))
                        }))
            }) {
                // Get variant index
                let variant_idx = data[*offset];
                *offset += 1;
                
                // Extract variant index as usize
                let bytes = variant_idx.to_bytes_be();
                let mut buf = [0u8; 8];
                buf.copy_from_slice(&bytes[24..32]);
                let idx = u64::from_be_bytes(buf) as usize;
                
                // Get variants
                if let Some(variants) = enum_def.get("variants").and_then(|v| v.as_array()) {
                    if idx < variants.len() {
                        if let Some(variant) = variants.get(idx) {
                            if let Some(variant_name) = variant.get("name").and_then(|v| v.as_str()) {
                                // If variant has a type, deserialize it; otherwise it's unit variant
                                if let Some(variant_type_val) = variant.get("type") {
                                    if let Some(variant_type_str) = variant_type_val.as_str() {
                                        if variant_type_str != "()" {
                                            let inner_value = deserialize_type(data, offset, variant_type_str, abi)?;
                                            let mut obj = serde_json::Map::new();
                                            obj.insert(variant_name.to_string(), inner_value);
                                            return Ok(Value::Object(obj));
                                        }
                                    }
                                }
                                // Unit variant - just return the variant name
                                return Ok(Value::String(variant_name.to_string()));
                            }
                        }
                    }
                }
            }
        }
    }

    // Handle structs - need to find struct definition in ABI
    let struct_name = if let Some(name) = type_str.strip_prefix("struct ") {
        name
    } else {
        type_str
    };

    if let Some(struct_def) = find_struct_in_abi(abi, struct_name) {
        if let Some(members) = struct_def.get("members").and_then(|v| v.as_array()) {
            // Use serde_json::Map which preserves insertion order (uses IndexMap internally)
            // Iterate through members in ABI order to maintain struct field ordering
            let mut obj = serde_json::Map::new();
            for member in members {
                if let (Some(name), Some(member_type)) = (
                    member.get("name").and_then(|v| v.as_str()),
                    member.get("type").and_then(|v| v.as_str()),
                ) {
                    let value = deserialize_type(data, offset, member_type, abi)?;
                    // Insert in order - serde_json::Map preserves insertion order
                    obj.insert(name.to_string(), value);
                }
            }
            return Ok(Value::Object(obj));
        }
    }

    // Fallback: treat as felt252
    let value = data[*offset];
    *offset += 1;
    Ok(Value::String(format!("0x{:x}", value)))
}

// ANSI escape codes for formatting
const BOLD: &str = "\x1b[1m";
const RESET: &str = "\x1b[0m";

// Custom formatter that preserves struct field order and makes values bold
fn print_formatted_struct(
    struct_name: &str,
    value: &Value,
    abi: Option<&Value>,
    indent: usize,
    show_struct_names: bool,
) -> Result<(), Error> {
    let indent_str = "  ".repeat(indent);
    
    // If it's an object (struct), print with preserved order
    if let Value::Object(map) = value {
        // Print struct name with the given indent level (if enabled)
        if show_struct_names {
            print!("{}{}{}{} {{", indent_str, BOLD, struct_name, RESET);
        } else {
            print!("{}{{", indent_str);
        }
        
        if map.is_empty() {
            print!(" }}");
            return Ok(());
        }
        
        println!();
        
        // Get struct definition from ABI to maintain field order
        if let Some(abi_val) = abi {
            if let Some(abi_array) = abi_val.as_array() {
                if let Some(struct_def) = abi_array.iter().find(|item| {
                    item.get("type") == Some(&Value::String("struct".to_string()))
                        && (item.get("name").and_then(|v| v.as_str()).map_or(false, |n| {
                            n == struct_name || n.ends_with(&format!("::{}", struct_name))
                        }))
                }) {
                    if let Some(members) = struct_def.get("members").and_then(|v| v.as_array()) {
                        // Print fields in ABI order
                        // Fields should be indented one level more than the struct name
                        let field_indent_str = "  ".repeat(indent + 1);
                        for (idx, member) in members.iter().enumerate() {
                            if let Some(name) = member.get("name").and_then(|v| v.as_str()) {
                                if let Some(field_value) = map.get(name) {
                                    print!("{}  \"{}\": ", field_indent_str, name);
                                    // Field values should be at the same indent as the field name
                                    // Fields are at indent+1, so pass indent+1 to the formatter
                                    print_formatted_value(field_value, abi, indent + 1, show_struct_names)?;
                                    if idx < members.len() - 1 {
                                        println!(",");
                                    } else {
                                        println!();
                                    }
                                }
                            }
                        }
                        print!("{}}}", indent_str);
                        return Ok(());
                    }
                }
            }
        }
        
        // Fallback: print in map order (which should be preserved)
        // Fields should be indented one level more than the struct name
        let field_indent_str = "  ".repeat(indent + 1);
        let entries: Vec<_> = map.iter().collect();
        for (idx, (key, val)) in entries.iter().enumerate() {
            print!("{}  \"{}\": ", field_indent_str, key);
            // Fields are at indent+1, so pass indent+1 to the formatter
            print_formatted_value(val, abi, indent + 1, show_struct_names)?;
            if idx < entries.len() - 1 {
                println!(",");
            } else {
                println!();
            }
        }
        print!("{}}}", indent_str);
    } else {
        // Not a struct, just print the value
        print_formatted_value(value, abi, indent, show_struct_names)?;
    }
    
    Ok(())
}

fn print_formatted_value(value: &Value, abi: Option<&Value>, indent: usize, show_struct_names: bool) -> Result<(), Error> {
    match value {
        Value::Null => print!("{}null{}", BOLD, RESET),
        Value::Bool(b) => print!("{}{}{}", BOLD, b, RESET),
        Value::Number(n) => print!("{}{}{}", BOLD, n, RESET),
        Value::String(s) => {
            print!("{}\"{}\"{}", BOLD, s, RESET);
        }
        Value::Array(arr) => {
            if arr.is_empty() {
                print!("[]");
            } else {
                // Check if all elements are small numeric values (u32 or smaller)
                let is_small_numeric = arr.iter().all(|v| {
                    match v {
                        Value::Number(_) => true,
                        Value::String(s) => s.parse::<u32>().is_ok(),
                        _ => false,
                    }
                });
                
                // Check if all elements are enum strings (short string values, likely enum variants)
                let is_enum_array = arr.iter().all(|v| {
                    if let Value::String(s) = v {
                        // Check if it's a short string (likely enum) and not a number
                        s.len() <= 10 && s.parse::<u32>().is_err()
                    } else {
                        false
                    }
                });
                
                if is_small_numeric && arr.len() <= 10 {
                    // Print small numeric arrays on one line
                    print!("[");
                    for (idx, item) in arr.iter().enumerate() {
                        print_formatted_value(item, abi, indent, show_struct_names)?;
                        if idx < arr.len() - 1 {
                            print!(", ");
                        }
                    }
                    print!("]");
                } else if is_enum_array {
                    // Print enum arrays compactly with multiple values per line (4 per line)
                    // Calculate column widths for alignment
                    let items_per_line = 4;
                    let num_lines = (arr.len() + items_per_line - 1) / items_per_line;
                    let mut column_widths = vec![0; items_per_line];
                    
                    // Find maximum width for each column
                    for (idx, item) in arr.iter().enumerate() {
                        if let Value::String(s) = item {
                            let col = idx % items_per_line;
                            column_widths[col] = column_widths[col].max(s.len());
                        }
                    }
                    
                    println!("[");
                    let indent_str = "  ".repeat(indent);
                    for (idx, item) in arr.iter().enumerate() {
                        let is_line_start = idx % items_per_line == 0;
                        let is_line_end = (idx + 1) % items_per_line == 0 || idx == arr.len() - 1;
                        let col = idx % items_per_line;
                        
                        if is_line_start {
                            print!("{}    ", indent_str);
                        }
                        
                        // Print value with padding for column alignment
                        if let Value::String(s) = item {
                            let width = column_widths[col];
                            print!("{}\"{}\"{}", BOLD, s, RESET);
                            if !is_line_end && col < items_per_line - 1 {
                                // Add padding to align next column
                                let padding = width.saturating_sub(s.len()) + 2; // +2 for ", "
                                print!(",{}", " ".repeat(padding));
                            }
                        } else {
                            print_formatted_value(item, abi, indent, show_struct_names)?;
                            if !is_line_end {
                                print!(", ");
                            }
                        }
                        
                        if is_line_end {
                            println!(",");
                        } else if idx == arr.len() - 1 {
                            println!();
                        }
                    }
                    print!("{}  ]", indent_str);
                } else {
                    // Print larger arrays or non-numeric arrays with line breaks
                    println!("[");
                    let indent_str = "  ".repeat(indent);
                    // Array elements are indented by 4 spaces from the array start
                    // So if array is at indent N, elements are at N+2
                    let element_indent = indent + 2;
                    for (idx, item) in arr.iter().enumerate() {
                        // For array elements, we print them at element_indent level
                        // The formatter should use this indent level directly
                        print_formatted_value(item, abi, element_indent, show_struct_names)?;
                        if idx < arr.len() - 1 {
                            println!(",");
                        } else {
                            println!();
                        }
                    }
                    print!("{}  ]", indent_str);
                }
            }
        }
        Value::Object(map) => {
            // Nested struct - try to find struct name from ABI
            // Look for a struct in ABI that has matching field names
            let struct_name = if let Some(abi_val) = abi {
                if let Some(abi_array) = abi_val.as_array() {
                    // Try to find a struct that matches this object's fields
                    abi_array
                        .iter()
                        .find_map(|item| {
                            if item.get("type") == Some(&Value::String("struct".to_string())) {
                                if let Some(members) = item.get("members").and_then(|v| v.as_array()) {
                                    // Check if all members match
                                    let all_match = members.iter().all(|m| {
                                        m.get("name").and_then(|v| v.as_str()).map_or(false, |name| {
                                            map.contains_key(name)
                                        })
                                    });
                                    if all_match && !members.is_empty() {
                                        item.get("name").and_then(|v| v.as_str())
                                            .map(|n| n.split("::").last().unwrap_or(n).to_string())
                                    } else {
                                        None
                                    }
                                } else {
                                    None
                                }
                            } else {
                                None
                            }
                        })
                        .unwrap_or_else(|| "struct".to_string())
                } else {
                    "struct".to_string()
                }
            } else {
                "struct".to_string()
            };
            
            // Use the struct formatter for nested structs
            print_formatted_struct(&struct_name, value, abi, indent, show_struct_names)?;
        }
    }
    Ok(())
}

fn print_basic_format(preimage_data: &[Felt252]) {
    println!("  Values ({} total):", preimage_data.len());
    for (idx, felt) in preimage_data.iter().enumerate() {
        let hex_str = format!("0x{:x}", felt);

        // Try to interpret as different types for better readability
        let bytes = felt.to_bytes_be();
        let as_u64 = u64::from_be_bytes([
            bytes[24], bytes[25], bytes[26], bytes[27], bytes[28], bytes[29], bytes[30], bytes[31],
        ]);
        let as_u32 = u32::from_be_bytes([bytes[28], bytes[29], bytes[30], bytes[31]]);
        let as_u16 = u16::from_be_bytes([bytes[30], bytes[31]]);
        let as_u8 = bytes[31];

        print!("    [{}] {}", idx, hex_str);

        // Show alternative interpretations if they're reasonable
        if as_u64 < 1000000 {
            print!(" (decimal: {})", as_u64);
        }
        if as_u32 < 1000000 && as_u32 > 0 {
            print!(" (u32: {})", as_u32);
        }
        if as_u16 < 10000 && as_u16 > 0 {
            print!(" (u16: {})", as_u16);
        }
        if as_u8 < 255 && as_u8 > 0 {
            print!(" (u8: {})", as_u8);
        }
        println!();
    }
}

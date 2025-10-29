use core::cmp::min;
use core::integer::u128_byte_reverse;
use core::num::traits::{BitSize, Bounded, One, SaturatingAdd, Zero};
use core::panic_with_felt252;
use keccak::cairo_keccak;


#[derive(Clone, Debug, Serde, Destruct)]
pub struct ByteCodeLeWords {
    pub words64bit: Array<u64>,
    pub lastInputWord: u64,
    pub lastInputNumBytes: usize,
}

#[derive(Clone, Debug, Serde, Destruct)]
pub struct ByteCode {
    pub bytes: Span<u8>,
}

#[generate_trait]
pub impl OriginalByteCode of OriginalByteCodeTrait {
    fn get_original(self: ByteCodeLeWords) -> ByteCode {
        let mut bytes: Array<u8> = Default::default();

        for word in self.words64bit {
            //? It's actually big endian, but we're using little endian to flip le to be
            let word_bytes = word.to_le_bytes_padded();
            bytes.append_span(word_bytes);
        }

        //? It's actually big endian, but we're using little endian to flip le to be
        let last_input_word_bytes = self.lastInputWord.to_le_bytes_padded();
        for i in 0..self.lastInputNumBytes {
            let byte = last_input_word_bytes.at(i);
            bytes.append(*byte);
        }

        ByteCode { bytes: bytes.span() }
    }
}

pub trait ToBytes<T> {
    /// Unpacks a type T into a span of big endian bytes
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytes representation of the value in big endian.
    fn to_be_bytes(self: T) -> Span<u8>;
    /// Unpacks a type T into a span of big endian bytes, padded to the byte size of T
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytesrepresentation of the value in big endian padded to the byte size of T.
    fn to_be_bytes_padded(self: T) -> Span<u8>;
    /// Unpacks a type T into a span of little endian bytes
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytes representation of the value in little endian.
    fn to_le_bytes(self: T) -> Span<u8>;
    /// Unpacks a type T into a span of little endian bytes, padded to the byte size of T
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytesrepresentation of the value in little endian padded to the byte size of T.
    fn to_le_bytes_padded(self: T) -> Span<u8>;
}

pub impl ToBytesImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Mul<T>,
    +BitAnd<T>,
    +Bitshift<T>,
    +BitSize<T>,
    +BytesUsedTrait<T>,
    +Into<u8, T>,
    +TryInto<T, u8>,
    +Copy<T>,
    +Drop<T>,
    +core::ops::AddAssign<T, T>,
    +PartialEq<T>,
> of ToBytes<T> {
    fn to_be_bytes(self: T) -> Span<u8> {
        let bytes_used = self.bytes_used();

        let one = One::<T>::one();
        let two = one + one;
        let eight = two * two * two;

        // 0xFF
        let mask = Bounded::<u8>::MAX.into();

        let mut bytes: Array<u8> = Default::default();
        let mut i: u8 = 0;
        while i != bytes_used {
            let val = Bitshift::<T>::shr(self, eight * (bytes_used - i - 1).into());
            bytes.append((val & mask).try_into().unwrap());
            i += 1;
        }

        bytes.span()
    }

    fn to_be_bytes_padded(mut self: T) -> Span<u8> {
        let padding = (BitSize::<T>::bits() / 8);
        self.to_be_bytes().pad_left_with_zeroes(padding)
    }

    fn to_le_bytes(mut self: T) -> Span<u8> {
        let bytes_used = self.bytes_used();
        let one = One::<T>::one();
        let two = one + one;
        let eight = two * two * two;

        // 0xFF
        let mask = Bounded::<u8>::MAX.into();

        let mut bytes: Array<u8> = Default::default();

        let mut i: u8 = 0;
        while i != bytes_used {
            let val = self.shr(eight * i.into());
            bytes.append((val & mask).try_into().unwrap());
            i += 1;
        }

        bytes.span()
    }

    fn to_le_bytes_padded(mut self: T) -> Span<u8> {
        let padding = (BitSize::<T>::bits() / 8);
        self.to_le_bytes().slice_right_padded(0, padding)
    }
}

pub trait Bitshift<T> {
    /// Shift a number left by a given number of bits.
    ///
    /// # Arguments
    ///
    /// * `self` - The number to shift
    /// * `shift` - The number of bits to shift by
    ///
    /// # Returns
    ///
    /// The result of shifting `self` left by `shift` bits
    ///
    /// # Panics
    ///
    /// Panics if the shift is greater than 255.
    /// Panics if the result overflows the type T.
    fn shl(self: T, shift: T) -> T;

    /// Shift a number right by a given number of bits.
    ///
    /// # Arguments
    ///
    /// * `self` - The number to shift
    /// * `shift` - The number of bits to shift by
    ///
    /// # Returns
    ///
    /// The result of shifting `self` right by `shift` bits
    ///
    /// # Panics
    ///
    /// Panics if the shift is greater than 255.
    fn shr(self: T, shift: T) -> T;
}

impl BitshiftImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Div<T>,
    +Mul<T>,
    +Exponentiation<T>,
    +Copy<T>,
    +Drop<T>,
    +PartialOrd<T>,
    +BitSize<T>,
    +TryInto<usize, T>,
> of Bitshift<T> {
    fn shl(self: T, shift: T) -> T {
        // if we shift by more than nb_bits of T, the result is 0
        // we early return to save gas and prevent unexpected behavior
        if shift > BitSize::<T>::bits().try_into().unwrap() - One::one() {
            panic_with_felt252('mul Overflow');
        }
        let two = One::one() + One::one();
        self * two.pow(shift)
    }

    fn shr(self: T, shift: T) -> T {
        // early return to save gas if shift > nb_bits of T
        if shift > BitSize::<T>::bits().try_into().unwrap() - One::one() {
            panic_with_felt252('mul Overflow');
        }
        let two = One::one() + One::one();
        self / two.pow(shift)
    }
}


pub trait Exponentiation<T> {
    /// Raise a number to a power.
    ///
    /// # Arguments
    ///
    /// * `self` - The base number
    /// * `exponent` - The exponent to raise the base to
    ///
    /// # Returns
    ///
    /// The result of raising `self` to the power of `exponent`
    ///
    /// # Panics
    ///
    /// Panics if the result overflows the type T.
    fn pow(self: T, exponent: T) -> T;
}

impl ExponentiationImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Mul<T>,
    +Div<T>,
    +BitAnd<T>,
    +PartialEq<T>,
    +Copy<T>,
    +Drop<T>,
> of Exponentiation<T> {
    fn pow(self: T, mut exponent: T) -> T {
        let zero = Zero::zero();
        if exponent.is_zero() {
            return One::one();
        }
        if self.is_zero() {
            return zero;
        }
        let one = One::one();
        let mut result = one;
        let mut base = self;
        let two = one + one;

        loop {
            if exponent & one == one {
                result = result * base;
            }

            exponent = exponent / two;
            if exponent == zero {
                break result;
            }

            base = base * base;
        }
    }
}

pub trait BytesUsedTrait<T> {
    /// Returns the number of bytes used to represent a `T` value.
    /// # Arguments
    /// * `self` - The value to check.
    /// # Returns
    /// The number of bytes used to represent the value.
    fn bytes_used(self: T) -> u8;
}

pub impl U8BytesUsedTraitImpl of BytesUsedTrait<u8> {
    fn bytes_used(self: u8) -> u8 {
        if self == 0 {
            return 0;
        }

        return 1;
    }
}

pub impl USizeBytesUsedTraitImpl of BytesUsedTrait<usize> {
    fn bytes_used(self: usize) -> u8 {
        if self < 0x10000 { // 256^2
            if self < 0x100 { // 256^1
                if self == 0 {
                    return 0;
                } else {
                    return 1;
                };
            }
            return 2;
        } else {
            if self < 0x1000000 { // 256^3
                return 3;
            }
            return 4;
        }
    }
}

pub impl U64BytesUsedTraitImpl of BytesUsedTrait<u64> {
    fn bytes_used(self: u64) -> u8 {
        if self <= Bounded::<u32>::MAX.into() { // 256^4
            return BytesUsedTrait::<u32>::bytes_used(self.try_into().unwrap());
        } else {
            if self < 0x1000000000000 { // 256^6
                if self < 0x10000000000 {
                    if self < 0x100000000 {
                        return 4;
                    }
                    return 5;
                }
                return 6;
            } else {
                if self < 0x100000000000000 { // 256^7
                    return 7;
                } else {
                    return 8;
                }
            }
        }
    }
}

pub impl U128BytesTraitUsedImpl of BytesUsedTrait<u128> {
    fn bytes_used(self: u128) -> u8 {
        let (u64high, u64low) = u128_split(self);
        if u64high == 0 {
            return BytesUsedTrait::<u64>::bytes_used(u64low.try_into().unwrap());
        } else {
            return BytesUsedTrait::<u64>::bytes_used(u64high.try_into().unwrap()) + 8;
        }
    }
}

pub impl U256BytesUsedTraitImpl of BytesUsedTrait<u256> {
    fn bytes_used(self: u256) -> u8 {
        if self.high == 0 {
            return BytesUsedTrait::<u128>::bytes_used(self.low.try_into().unwrap());
        } else {
            return BytesUsedTrait::<u128>::bytes_used(self.high.try_into().unwrap()) + 16;
        }
    }
}

#[generate_trait]
pub impl U8SpanExImpl of U8SpanExTrait {
    /// Computes the keccak256 hash of a bytes message
    /// # Arguments
    /// * `self` - The input bytes as a Span<u8>
    /// # Returns
    /// * The keccak256 hash as a u256
    fn compute_keccak256_hash(self: Span<u8>) -> u256 {
        let (mut keccak_input, last_input_word, last_input_num_bytes) = self.to_u64_words();
        let hash = cairo_keccak(ref keccak_input, :last_input_word, :last_input_num_bytes)
            .reverse_endianness();

        hash
    }

    /// Transforms a Span<u8> into an Array of u64 full words, a pending u64 word and its length in
    /// bytes
    /// # Arguments
    /// * `self` - The input bytes as a Span<u8>
    /// # Returns
    /// * A tuple containing:
    ///   - An Array<u64> of full words
    ///   - A u64 representing the last (potentially partial) word
    ///   - A usize representing the number of bytes in the last word
    fn to_u64_words(self: Span<u8>) -> (Array<u64>, u64, usize) {
        let nonzero_8: NonZero<u32> = 8_u32.try_into().unwrap();
        let (full_u64_word_count, last_input_num_bytes) = DivRem::div_rem(self.len(), nonzero_8);

        let mut u64_words: Array<u64> = Default::default();
        let mut byte_counter: u8 = 0;
        let mut pending_word: u64 = 0;
        let mut u64_word_counter: usize = 0;

        while u64_word_counter != full_u64_word_count {
            if byte_counter == 8 {
                u64_words.append(pending_word);
                byte_counter = 0;
                pending_word = 0;
                u64_word_counter += 1;
            }
            pending_word += match self.get(u64_word_counter * 8 + byte_counter.into()) {
                Option::Some(byte) => {
                    let byte: u64 = (*byte.unbox()).into();
                    // Accumulate pending_word in a little endian manner
                    byte.shl(8_u64 * byte_counter.into())
                },
                Option::None => { break; },
            };
            byte_counter += 1;
        }

        // Fill the last input word
        let mut last_input_word: u64 = 0;
        let mut byte_counter: u8 = 0;

        // We enter a second loop for clarity.
        // O(2n) should be okay
        // We might want to regroup every computation into a single loop with appropriate `if`
        // branching For optimisation
        while byte_counter.into() != last_input_num_bytes {
            last_input_word += match self.get(full_u64_word_count * 8 + byte_counter.into()) {
                Option::Some(byte) => {
                    let byte: u64 = (*byte.unbox()).into();
                    byte.shl(8_u64 * byte_counter.into())
                },
                Option::None => { break; },
            };
            byte_counter += 1;
        }

        (u64_words, last_input_word, last_input_num_bytes)
    }

    /// Returns right padded slice of the span, starting from index offset
    /// If offset is greater than the span length, returns an empty span
    /// # Examples
    ///
    /// ```
    ///   let span = [0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
    ///   let expected = [0x04, 0x05, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0].span();
    ///   let result = span.slice_right_padded(4, 10);
    ///   assert_eq!(result, expected);
    /// ```
    /// # Arguments
    /// * `offset` - The offset to start the slice from
    /// * `len` - The length of the slice
    ///
    /// # Returns
    /// * A span of length `len` starting from `offset` right padded with 0s if `offset` is greater
    /// than the span length, returns an empty span of length `len` if offset is grearter than the
    /// span length
    fn slice_right_padded(self: Span<u8>, offset: usize, len: usize) -> Span<u8> {
        let start = if offset <= self.len() {
            offset
        } else {
            self.len()
        };

        let end = min(start.saturating_add(len), self.len());

        let slice = self.slice(start, end - start);
        // Save appending to span for this case as it is more efficient to just return the slice
        if slice.len() == len {
            return slice;
        }

        // Copy the span
        let mut arr = array![];
        arr.append_span(slice);

        while arr.len() != len {
            arr.append(0);
        }

        arr.span()
    }

    /// Clones and pads the given span with 0s to the right to the given length
    /// If data is more than the given length, it is truncated from the right side
    /// # Arguments
    /// * `self` - The input bytes as a Span<u8>
    /// * `len` - The desired length of the padded span
    /// # Returns
    /// * A Span<u8> of length `len` right padded with 0s if the span length is less than `len`,
    ///   or truncated from the right if the span length is greater than `len`
    /// # Examples
    /// ```
    /// let span = array![1, 2, 3].span();
    /// let padded = span.pad_right_with_zeroes(5);
    /// assert_eq!(padded, array![1, 2, 3, 0, 0].span());
    /// ```
    fn pad_right_with_zeroes(self: Span<u8>, len: usize) -> Span<u8> {
        if self.len() >= len {
            return self.slice(0, len);
        }

        // Create a new array with the original data
        let mut arr = array![];
        for i in self {
            arr.append(*i);
        }

        // Pad with zeroes
        while arr.len() != len {
            arr.append(0);
        }

        arr.span()
    }


    /// Clones and pads the given span with 0s to the left to the given length
    /// If data is more than the given length, it is truncated from the right side
    /// # Arguments
    /// * `self` - The input bytes as a Span<u8>
    /// * `len` - The desired length of the padded span
    /// # Returns
    /// * A Span<u8> of length `len` left padded with 0s if the span length is less than `len`,
    ///   or truncated from the right if the span length is greater than `len`
    /// # Examples
    /// ```
    /// let span = array![1, 2, 3].span();
    /// let padded = span.pad_left_with_zeroes(5);
    /// assert_eq!(padded, array![0, 0, 1, 2, 3].span());
    /// ```
    fn pad_left_with_zeroes(self: Span<u8>, len: usize) -> Span<u8> {
        if self.len() >= len {
            return self.slice(0, len);
        }

        // left pad with 0
        let mut arr = array![];
        while arr.len() != (len - self.len()) {
            arr.append(0);
        }

        // append the data
        let mut i = 0;
        while i != self.len() {
            arr.append(*self[i]);
            i += 1;
        }

        arr.span()
    }
}

/// Splits a u128 into two u64 parts, representing the high and low parts of the input.
///
/// # Arguments
/// * `input` - The u128 value to be split.
///
/// # Returns
/// A tuple containing two u64 values, where the first element is the high part of the input
/// and the second element is the low part of the input.
pub fn u128_split(input: u128) -> (u64, u64) {
    let (high, low) = core::integer::u128_safe_divmod(
        input, 0x10000000000000000_u128.try_into().unwrap(),
    );

    (high.try_into().unwrap(), low.try_into().unwrap())
}

#[generate_trait]
pub impl U256Impl of U256Trait {
    /// Reverse the endianness of an u256
    fn reverse_endianness(self: u256) -> u256 {
        let new_low = u128_byte_reverse(self.high);
        let new_high = u128_byte_reverse(self.low);
        u256 { low: new_low, high: new_high }
    }
}

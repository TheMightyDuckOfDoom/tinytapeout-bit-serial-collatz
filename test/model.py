#!/usr/bin/env python3
# SPDX-FileCopyrightText: © 2026 Tobias Senti
# SPDX-License-Identifier: Apache-2.0

def collatz_sw(n):
    if n % 2 == 0:
        return n // 2
    else:
        return 3 * n + 1

def collatz_hw_naive(n):
    if n & 1 == 0:
        return n >> 1
    else:
        return (n << 1) + n + 1

def collatz_hw_bitserial(n):
    # convert to binary array
    SIZE = 32
    bn = [0 for _ in range(SIZE)]
    for i in range(SIZE):
        bn[i] = (n >> i) & 1

    if bn[0] == 0:
        # even: n >> 1
        # shift right by one bit
        for i in range(SIZE-1):
            bn[i] = bn[i+1]
        bn[SIZE-1] = 0
    else:
        # odd: 3*n + 1 == (n << 1) + n + 1
        carry = 1 # for the +1
        previous_bit = 0 # used for the n << 1 part
        for i in range(SIZE):
            # store previous bit before overwriting it
            current_bit = bn[i]

            bn[i] = bn[i] ^ previous_bit ^ carry
            carry = (current_bit & previous_bit) | (carry & (current_bit ^ previous_bit))

            previous_bit = current_bit

    # convet back to integer
    result = 0
    for i in range(SIZE):
        result |= (bn[i] << i)

    return result

def run_collatz(start, fn):
    n = start
    steps = 0
    step_counter_bits = 0
    n_bits = 0
    while n != 1 and n != 0:
        n = fn(n)
        steps += 1
        step_counter_bits = max(step_counter_bits, steps.bit_length())
        n_bits = max(n_bits, n.bit_length())
    return steps, step_counter_bits, n_bits

max_step_bits = 0
max_n_bits = 0
for i in range(1000000):
    # i = 3012445987290400330380289851637892354190268 # fits into 144 bits
    # i = 9538163849286484684936098584142661875319637 # needs 145 bits
    # random 256 bit number
    #i = 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
    # random 512 bit number
    i = 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
    steps, step_counter_bits, n_bits = run_collatz(i, collatz_sw)
    print(f"{i}: {steps} steps, step counter bits needed: {step_counter_bits}, n bits needed: {n_bits}")
    max_step_bits = max(max_step_bits, step_counter_bits)
    max_n_bits = max(max_n_bits, n_bits)
    break

print(f"Maximum step counter bits needed: {max_step_bits}")
print(f"Maximum n bits needed: {max_n_bits}")

# for i in range(1, 1000):
#     steps_sw = run_collatz(i, collatz_sw)
#     steps_hw_naive = run_collatz(i, collatz_hw_naive)
#     steps_hw_bitserial = run_collatz(i, collatz_hw_bitserial)
#     print(f"{i}: {steps_sw} steps (SW), {steps_hw_naive} steps (HW Naive), {steps_hw_bitserial} steps (HW Bit-Serial)")
#     assert steps_sw == steps_hw_naive, f"Mismatch for {i}: {steps_sw} (SW) vs {steps_hw_naive} (HW Naive)"
#     assert steps_sw == steps_hw_bitserial, f"Mismatch for {i}: {steps_sw} (SW) vs {steps_hw_bitserial} (HW Bit-Serial)"

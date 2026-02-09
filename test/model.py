#!/usr/bin/env python3

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
    while n != 1:
        n = fn(n)
        steps += 1
    return steps

for i in range(1, 1000):
    steps_sw = run_collatz(i, collatz_sw)
    steps_hw_naive = run_collatz(i, collatz_hw_naive)
    steps_hw_bitserial = run_collatz(i, collatz_hw_bitserial)
    print(f"{i}: {steps_sw} steps (SW), {steps_hw_naive} steps (HW Naive), {steps_hw_bitserial} steps (HW Bit-Serial)")
    assert steps_sw == steps_hw_naive, f"Mismatch for {i}: {steps_sw} (SW) vs {steps_hw_naive} (HW Naive)"
    assert steps_sw == steps_hw_bitserial, f"Mismatch for {i}: {steps_sw} (SW) vs {steps_hw_bitserial} (HW Bit-Serial)"

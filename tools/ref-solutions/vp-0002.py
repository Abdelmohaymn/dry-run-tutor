"""vp-0002 Add Digits -- Add Digits (LeetCode 258)."""


def solve(num):
    while num >= 10:
        num = sum(int(d) for d in str(num))
    return num


def check_input(num):
    assert 0 <= num <= 2**31 - 1

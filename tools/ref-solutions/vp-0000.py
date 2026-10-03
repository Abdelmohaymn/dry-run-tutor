"""vp-0000 Largest in the list (own warm-up)."""


def solve(nums):
    return max(nums)


def check_input(nums):
    assert 1 <= len(nums) <= 10**7
    assert all(-10**9 <= x <= 10**9 for x in nums)
    assert nums != sorted(nums), "the list is not sorted"

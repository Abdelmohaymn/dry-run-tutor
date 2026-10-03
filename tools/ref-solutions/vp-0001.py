"""vp-0001 Pair Sum -- Two Sum (LeetCode 1)."""
import json


def solve(nums, target):
    seen = {}
    for i, x in enumerate(nums):
        if target - x in seen:
            return [seen[target - x], i]
        seen[x] = i
    return None


def check_input(nums, target):
    assert 2 <= len(nums) <= 10**7
    assert all(-10**9 <= x <= 10**9 for x in nums)
    pairs = [(i, j) for i in range(len(nums)) for j in range(i + 1, len(nums)) if nums[i] + nums[j] == target]
    assert len(pairs) == 1, f"exactly one valid pair, found {len(pairs)}"


def same(got, want, inputs):
    # The two positions can be listed in either order.
    return sorted(got) == sorted(json.loads(want))

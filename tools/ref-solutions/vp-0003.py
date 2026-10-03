"""vp-0003 First Palindromic String -- LeetCode 2108."""


def solve(words):
    return next((w for w in words if w == w[::-1]), "")


def check_input(words):
    assert 1 <= len(words) <= 100
    assert all(1 <= len(w) <= 100 for w in words)
    assert all(c.isascii() and c.islower() for w in words for c in w)

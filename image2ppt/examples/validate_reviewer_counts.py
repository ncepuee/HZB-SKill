#!/usr/bin/env python3
"""
Example: keep data separate from rendering and validate totals first.
"""

reviewers = [
    {"name": "Reviewer 1", "r1": 10, "r2": 0},
    {"name": "Reviewer 2", "r1": 4,  "r2": 0},
    {"name": "Reviewer 3", "r1": 6,  "r2": 4},
    {"name": "Reviewer 4", "r1": 7,  "r2": 6},
    {"name": "Reviewer 5", "r1": 6,  "r2": 0},
]

round1_total = sum(x["r1"] for x in reviewers)
round2_total = sum(x["r2"] for x in reviewers)
grand_total = round1_total + round2_total

assert round1_total == 33
assert round2_total == 10
assert grand_total == 43

print("Round 1:", round1_total)
print("Round 2:", round2_total)
print("Grand total:", grand_total)

#!/bin/bash

guard_dangling_reference() {
  local input="$1"
  local text
  text=$(dd_assistant_text "$input" 100000)
  [ -z "$text" ] && return 0
  dd_is_wip "$text" && return 0

  local reference
  reference=$(_dd_unexplained_point_reference "$text")
  [ -z "$reference" ] && return 0

  dd_emit_block dangling-reference "\"$reference\" points at items this message does not describe, and the operator does not scroll back to find them. Say in one sentence per item what it is, or drop the reference."
}

_dd_unexplained_point_reference() {
  python3 -c '
import re, sys

text = sys.stdin.read()
text = re.sub(r"(?ms)^[ \t]*(`{3,}|~{3,})[^\n]*\n.*?^[ \t]*\1[`~]*[ \t]*$", " ", text)
listed = set(re.findall(r"(?m)^\s*(?:[-*]\s+)?(?:\*\*)?(\d+)[.)](?!\d)", text))
for span in (r"`[^`\n]*`", r"https?://\S+", r"\"[^\"\n]*\"", "[\u201c\u201e][^\u201c\u201d\u201e\n]*\u201d"):
    text = re.sub(span, " ", text)

number = r"\d+(?!\d|[.,]\d)"
joiner = r"\s*(?:,|en|and|tot en met|t/m|to|through|-|\u2013)\s*"
reference = re.compile(r"\b(?:punt(?:en)?|points?|items?)\s+(" + number + r"(?:" + joiner + number + r")*)", re.I)
range_joiner = re.compile(r"^\s*(?:tot en met|t/m|to|through|-|\u2013)\s*$", re.I)

for match in reference.finditer(text):
    parts = re.split(r"(\d+)", match.group(1))
    numbers, joiners = parts[1::2], parts[2::2]
    wanted = {int(numbers[0])}
    for previous, between, current in zip(numbers, joiners, numbers[1:]):
        low, high = int(previous), int(current)
        if range_joiner.match(between) and low < high:
            wanted.update(range(low, high + 1))
        else:
            wanted.add(high)
    if any(str(n) not in listed for n in wanted):
        print(match.group(0).strip())
        break
' <<< "$1"
}

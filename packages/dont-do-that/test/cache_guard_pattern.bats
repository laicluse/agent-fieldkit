#!/usr/bin/env bats

setup() {
  GUARD="$BATS_TEST_DIRNAME/../hooks/guards/cache.sh"
  PATTERN=$(grep -A1 'grep -qiE' "$GUARD" | grep -oE '"\(het probleem is.*"' | sed 's/^"//; s/" *$//')
  [ -n "$PATTERN" ] || PATTERN=$(grep -oE '"\(het probleem is[^"]*"' "$GUARD" | sed 's/^"//; s/"$//')
  [ -n "$PATTERN" ]
}

matches() {
  echo "$1" | grep -qiE "$PATTERN"
}

@test "ignores js substring inside Dutch words after oude" {
  ! matches "oude en.yml (enige verschil: de zes lijstnummers)"
}

@test "reads oude as a whole word at most three words before the asset in the same sentence" {
  ! matches "De oude remote branch. Na \`bundle install\` zijn de gems bijgewerkt."
  matches "de oude bundle"
  matches "de oude versie van de bundle"
  matches "oude, JS bundle"
  matches "oude  assets"
  matches "oude **assets**"
  matches "oude \`assets\`"
  ! matches "een verouderde bundle"
  ! matches "de oude versie van de nieuwe bundle"
  ! matches "de oude remote branch van gisteren en daarna bundle install"
}

@test "still blocks stale JS bundle claims" {
  matches "de oude JS bundle staat nog in de browser"
}

@test "still blocks stale assets claims" {
  matches "vermoedelijk de oude assets van gisteren"
}

@test "a clean-profile comparison is evidence, not a rationalisation" {
  EVIDENCE=$(grep -oE 'grep -qiE "incognito[^"]*"' "$GUARD" | sed 's/^grep -qiE "//; s/"$//')
  [ -n "$EVIDENCE" ]
  echo "in een incognito venster laadt de demo wel goed" | grep -qiE "$EVIDENCE"
  ! echo "de browser cache houdt de oude versie vast" | grep -qiE "$EVIDENCE"
}

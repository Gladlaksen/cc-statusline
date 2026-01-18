#!/bin/bash
# Test script for beads integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Testing Beads Integration ==="
echo ""

# Create a temporary directory for testing
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Create a mock .beads directory
mkdir -p "$TEST_DIR/.beads"

# Create mock bd command
cat > "$TEST_DIR/bd" << 'MOCKBD'
#!/bin/bash
case "$1 $2" in
  "ready --json")
    echo '[{"id":"beads-001"},{"id":"beads-002"}]'
    ;;
  "list --status=in_progress")
    echo '[{"id":"beads-003"}]'
    ;;
  "blocked ")
    echo '[]'
    ;;
  *)
    echo '[]'
    ;;
esac
MOCKBD
chmod +x "$TEST_DIR/bd"

# Copy a test statusline with beads enabled
# We need to generate it manually since init is interactive
cat > "$TEST_DIR/statusline.sh" << 'STATUSLINE'
#!/bin/bash
input=$(cat)

# Check jq
HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
  HAS_JQ=1
fi

# Colors
use_color=1
beads_ready_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;114m'; fi; }
beads_wip_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;221m'; fi; }
beads_blocked_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;210m'; fi; }
rst() { if [ "$use_color" -eq 1 ]; then printf '\033[0m'; fi; }

# Beads extraction
beads_ready=""
beads_in_progress=""
beads_blocked=""

if command -v bd >/dev/null 2>&1 && [ -d ".beads" ]; then
  if [ "$HAS_JQ" -eq 1 ]; then
    beads_ready=$(bd ready --json 2>/dev/null | jq 'length' 2>/dev/null || echo "")
    beads_in_progress=$(bd list --status=in_progress --json 2>/dev/null | jq 'length' 2>/dev/null || echo "")
    beads_blocked=$(bd blocked --json 2>/dev/null | jq 'length' 2>/dev/null || echo "")
  else
    beads_ready=$(bd ready --json 2>/dev/null | grep -o '{' | wc -l | tr -d ' ')
    beads_in_progress=$(bd list --status=in_progress --json 2>/dev/null | grep -o '{' | wc -l | tr -d ' ')
    beads_blocked=$(bd blocked --json 2>/dev/null | grep -o '{' | wc -l | tr -d ' ')
  fi

  [ -z "$beads_ready" ] && beads_ready="0"
  [ -z "$beads_in_progress" ] && beads_in_progress="0"
  [ -z "$beads_blocked" ] && beads_blocked="0"
fi

# Display
echo "Beads Status:"
if [ -n "$beads_ready" ] || [ -n "$beads_in_progress" ] || [ -n "$beads_blocked" ]; then
  if [ "$beads_ready" != "0" ] || [ "$beads_in_progress" != "0" ] || [ "$beads_blocked" != "0" ]; then
    printf '📍 %s%s ready%s | %s%s wip%s' "$(beads_ready_color)" "$beads_ready" "$(rst)" "$(beads_wip_color)" "$beads_in_progress" "$(rst)"
    if [ "$beads_blocked" != "0" ]; then
      printf ' | %s%s blocked%s' "$(beads_blocked_color)" "$beads_blocked" "$(rst)"
    fi
    printf '\n'
  else
    echo "No beads issues found (all counts are 0)"
  fi
else
  echo "No beads data available"
fi
STATUSLINE
chmod +x "$TEST_DIR/statusline.sh"

# Run the test
echo "Test directory: $TEST_DIR"
echo "Running statusline in beads-enabled directory..."
echo ""

cd "$TEST_DIR"
export PATH="$TEST_DIR:$PATH"

# Verify mock bd works
echo "Mock bd ready --json output:"
bd ready --json
echo ""

# Run the statusline
echo "Statusline output:"
echo '{}' | ./statusline.sh
echo ""

echo "=== Test Complete ==="

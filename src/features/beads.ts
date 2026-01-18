export type BeadsFeature = {
  enabled: boolean
  showReady: boolean
  showInProgress: boolean
  showBlocked: boolean
}

export function generateBeadsBashCode(config: BeadsFeature, colors: boolean): string {
  if (!config.enabled) return ''

  const colorCode = colors ? `
# ---- beads colors ----
beads_ready_color() { if [ "$use_color" -eq 1 ]; then printf '\\033[38;5;114m'; fi; }   # soft green
beads_wip_color() { if [ "$use_color" -eq 1 ]; then printf '\\033[38;5;221m'; fi; }     # yellow
beads_blocked_color() { if [ "$use_color" -eq 1 ]; then printf '\\033[38;5;210m'; fi; } # light red/coral
` : `
beads_ready_color() { :; }
beads_wip_color() { :; }
beads_blocked_color() { :; }
`

  return `${colorCode}
# ---- beads issue tracking ----
beads_ready=""
beads_in_progress=""
beads_blocked=""

if command -v bd >/dev/null 2>&1 && [ -d ".beads" ]; then
  if [ "$HAS_JQ" -eq 1 ]; then
    # Use jq for reliable JSON parsing
    beads_ready=$(bd ready --json 2>/dev/null | jq 'length' 2>/dev/null || echo "")
    beads_in_progress=$(bd list --status=in_progress --json 2>/dev/null | jq 'length' 2>/dev/null || echo "")
    beads_blocked=$(bd blocked --json 2>/dev/null | jq 'length' 2>/dev/null || echo "")
  else
    # Bash fallback: count array elements by counting opening braces after first one
    beads_ready=$(bd ready --json 2>/dev/null | grep -o '{' | wc -l | tr -d ' ')
    beads_in_progress=$(bd list --status=in_progress --json 2>/dev/null | grep -o '{' | wc -l | tr -d ' ')
    beads_blocked=$(bd blocked --json 2>/dev/null | grep -o '{' | wc -l | tr -d ' ')
  fi

  # Default to 0 if empty
  [ -z "$beads_ready" ] && beads_ready="0"
  [ -z "$beads_in_progress" ] && beads_in_progress="0"
  [ -z "$beads_blocked" ] && beads_blocked="0"
fi`
}

export function generateBeadsDisplayCode(config: BeadsFeature, colors: boolean, emojis: boolean): string {
  if (!config.enabled) return ''

  const beadsEmoji = emojis ? '📍' : 'beads:'

  let displayParts: string[] = []

  if (config.showReady) {
    displayParts.push(`$(beads_ready_color)\${beads_ready} ready$(rst)`)
  }

  if (config.showInProgress) {
    displayParts.push(`$(beads_wip_color)\${beads_in_progress} wip$(rst)`)
  }

  if (config.showBlocked) {
    displayParts.push(`$(beads_blocked_color)\${beads_blocked} blocked$(rst)`)
  }

  const displayString = displayParts.join(' | ')

  return `
# beads display
if [ -n "$beads_ready" ] || [ -n "$beads_in_progress" ] || [ -n "$beads_blocked" ]; then
  if [ "$beads_ready" != "0" ] || [ "$beads_in_progress" != "0" ] || [ "$beads_blocked" != "0" ]; then
    printf '  ${beadsEmoji} ${displayString}'
  fi
fi`
}

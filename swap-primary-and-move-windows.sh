#!/usr/bin/env bash
#
# Swap the primary display between two monitors on KDE Plasma 6 (Wayland),
# then move every open window onto the new primary display.
#
# Dependencies: kscreen-doctor, jq, qdbus (qt6 flavour)

set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }

# --- dependencies -------------------------------------------------------------

command -v kscreen-doctor >/dev/null || die "kscreen-doctor not found (dnf install kscreen)"
command -v jq >/dev/null             || die "jq not found (dnf install jq)"

QDBUS=""
for cand in qdbus-qt6 qdbus6 qdbus; do
    if command -v "$cand" >/dev/null; then
        QDBUS=$cand
        break
    fi
done
[ -n "$QDBUS" ] || die "qdbus not found (dnf install qt6-qttools)"

# --- read current output configuration ----------------------------------------

json=$(kscreen-doctor --json) || die "kscreen-doctor --json failed"

mapfile -t outputs < <(jq -r '.outputs[] | select(.enabled) | .name' <<<"$json")
[ "${#outputs[@]}" -eq 2 ] || die "expected exactly 2 enabled outputs, found ${#outputs[@]}"

current_primary=$(jq -r '[.outputs[] | select(.enabled and .priority == 1) | .name] | first // empty' <<<"$json")

if [ "$current_primary" = "${outputs[0]}" ]; then
    new_primary=${outputs[1]}
    new_secondary=${outputs[0]}
else
    # Covers both "outputs[1] is primary" and "no primary detected".
    new_primary=${outputs[0]}
    new_secondary=${outputs[1]}
fi

# --- swap primary ---------------------------------------------------------------

echo "Setting primary display: $new_primary (was: ${current_primary:-none})"
kscreen-doctor "output.${new_primary}.priority.1" "output.${new_secondary}.priority.2" \
    || die "kscreen-doctor failed to apply new priorities"

# Let KWin settle before moving windows around.
sleep 0.5

# --- move all windows to the new primary via a transient KWin script ------------

kwin_js=$(mktemp --suffix=.js)
trap 'rm -f "$kwin_js"' EXIT

cat >"$kwin_js" <<EOF
const target = workspace.screens.find(s => s.name === "${new_primary}");
if (target) {
    for (const w of workspace.windowList()) {
        if (!w.normalWindow && !w.dialog) continue;  // panels, docks, etc.
        if (w.skipTaskbar) continue;                 // hidden utility windows
        if (!w.moveableAcrossScreens) continue;
        if (w.output !== target) {
            workspace.sendClientToScreen(w, target);
        }
    }
}
EOF

plugin_name="swap-primary-move-windows"

# Clear any leftover instance from a previous run that died mid-flight.
"$QDBUS" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$plugin_name" >/dev/null 2>&1 || true

script_id=$("$QDBUS" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$kwin_js" "$plugin_name") \
    || die "failed to load KWin script"
[[ "$script_id" =~ ^[0-9]+$ ]] || die "KWin refused to load the script (got: $script_id)"

"$QDBUS" org.kde.KWin "/Scripting/Script${script_id}" org.kde.kwin.Script.run \
    || die "failed to run KWin script"
"$QDBUS" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$plugin_name" >/dev/null

echo "Done: $new_primary is primary and all windows were moved to it."

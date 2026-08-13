#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT/AppStore/Screenshots/Source Captures"
OUTPUT_DIR="$PROJECT_ROOT/AppStore/Screenshots/Final"
MAGICK_BIN="${MAGICK_BIN:-/opt/homebrew/bin/magick}"
FONT_FILE="/System/Library/Fonts/SFNS.ttf"

if [[ ! -x "$MAGICK_BIN" ]]; then
    echo "ImageMagick was not found at $MAGICK_BIN" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

SCREENSHOT_TEMP="$(mktemp -d /private/tmp/work-island-store-shots.XXXXXX)"
trap 'rm -rf "$SCREENSHOT_TEMP"' EXIT

make_background() {
    local output="$1"

    "$MAGICK_BIN" \
        -size 1440x900 gradient:'#17192b-#080910' \
        "$output"
}

mask_window() {
    local source="$1"
    local output="$2"

    "$MAGICK_BIN" "$source" \
        \( -size 1133x747 xc:black \
            -fill white \
            -draw 'roundrectangle 0,0 1132,746 20,20' \) \
        -alpha off -compose CopyOpacity -composite \
        "$output"
}

mask_notch() {
    local source="$1"
    local output="$2"

    "$MAGICK_BIN" "$source" \
        \( -size 500x190 xc:black \
            -fill white \
            -draw 'roundrectangle 0,0 499,189 24,24' \) \
        -alpha off -compose CopyOpacity -composite \
        "$output"
}

compose_window() {
    local source_name="$1"
    local output_name="$2"
    local title="$3"
    local subtitle="$4"
    local background="$SCREENSHOT_TEMP/background-$output_name"
    local masked="$SCREENSHOT_TEMP/masked-$output_name"

    make_background "$background"
    mask_window "$SOURCE_DIR/$source_name" "$masked"

    "$MAGICK_BIN" "$background" \
        -font "$FONT_FILE" -fill white -pointsize 42 \
        -gravity northwest -annotate +154+68 "$title" \
        -font "$FONT_FILE" -fill '#B7BBCB' -pointsize 21 \
        -annotate +156+116 "$subtitle" \
        \( -size 1175x789 xc:none \
            -fill 'rgba(0,0,0,0.62)' \
            -draw 'roundrectangle 21,21 1154,768 24,24' \
            -blur 0x18 \) \
        -geometry +133+125 -compose over -composite \
        "$masked" -geometry +154+145 -compose over -composite \
        -strip -define png:color-type=2 \
        "$OUTPUT_DIR/$output_name"
}

compose_notch() {
    local background="$SCREENSHOT_TEMP/background-05-notch.png"
    local faded_window="$SCREENSHOT_TEMP/faded-dashboard.png"
    local masked_notch="$SCREENSHOT_TEMP/masked-notch.png"

    make_background "$background"
    mask_window "$SOURCE_DIR/dashboard-top.png" "$faded_window"
    mask_notch "$SOURCE_DIR/notch-active.png" "$masked_notch"

    "$MAGICK_BIN" "$background" \
        -font "$FONT_FILE" -fill white -pointsize 42 \
        -gravity northwest -annotate +154+68 'Controls that stay within reach.' \
        -font "$FONT_FILE" -fill '#B7BBCB' -pointsize 21 \
        -annotate +156+116 'Hover at the top of the screen to pause or finish.' \
        \( "$faded_window" -resize 900x \
            -alpha set -channel A -evaluate multiply 0.45 +channel \) \
        -geometry +270+330 -compose over -composite \
        \( "$masked_notch" -resize 700x266 \) \
        -geometry +370+175 -compose over -composite \
        -strip -define png:color-type=2 \
        "$OUTPUT_DIR/05-notch.png"
}

compose_window \
    "dashboard-top.png" \
    "01-dashboard.png" \
    "Your work, at a glance." \
    "Track today's focus and keep the current session close."

compose_window \
    "dashboard-analytics.png" \
    "02-analytics.png" \
    "Patterns you can act on." \
    "Explore task graphs and time distribution."

compose_window \
    "tasks.png" \
    "03-tasks.png" \
    "Tasks stay simple." \
    "Create reusable tasks and see where your time goes."

compose_window \
    "history.png" \
    "04-history.png" \
    "Every session, clearly recorded." \
    "Review your history and add notes whenever you need."

compose_notch

for screenshot in "$OUTPUT_DIR"/*.png; do
    dimensions="$($MAGICK_BIN identify -format '%wx%h' "$screenshot")"
    if [[ "$dimensions" != "1440x900" ]]; then
        echo "Unexpected dimensions for $screenshot: $dimensions" >&2
        exit 1
    fi
done

echo "Created five 1440x900 App Store screenshots in $OUTPUT_DIR"

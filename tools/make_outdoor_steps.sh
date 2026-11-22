#!/usr/bin/env bash
# Makes the outdoor footsteps from the four tile footsteps (Godot/sounds/footstep_tile_<n>.ogg):
# footstep_asphalt_<n>.ogg for the alley and footstep_sidewalk_<n>.ogg for the porch at the door.
# Each take is cut short to drop the tile's ring and low-passed (asphalt duller than the concrete
# sidewalk), with a short burst of grit under the heel.
# Needs ffmpeg and oggenc (brew install ffmpeg vorbis-tools).
# Usage: make_outdoor_steps.sh Godot/sounds
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <Godot/sounds>" >&2; exit 2; }
sounds=$1
fade=0.2   # where the take starts to fade out, in seconds
end=0.28   # where the take ends, in seconds

# make <surface> <cutoff Hz> <grit dB>
make() {
	local surface=$1 cutoff=$2 grit_db=$3
	for n in 1 2 3 4; do
		local source="$sounds/footstep_tile_$n.ogg"
		[ -f "$source" ] || { echo "$0: missing $source" >&2; exit 1; }
		ffmpeg -hide_banner -loglevel error -i "$source" \
			-f lavfi -i "anoisesrc=color=pink:sample_rate=44100:duration=0.25:seed=$n" \
			-filter_complex "[0]afade=t=out:st=$fade:d=$(awk "BEGIN{print $end - $fade}"),atrim=end=$end,highpass=f=70,lowpass=f=$cutoff,lowpass=f=$cutoff[step];\
[1]highpass=f=1800,lowpass=f=$((cutoff * 2)),afade=t=out:st=0:d=0.09,adelay=20,volume=${grit_db}dB[grit];\
[step][grit]amix=inputs=2:duration=first:normalize=0" \
			-map_metadata -1 -fflags +bitexact -c:a pcm_s16le -f wav - \
			| oggenc --quiet -q 4 -o "$sounds/footstep_${surface}_$n.ogg" -
	done
}

make asphalt 1500 -14
make sidewalk 4000 -18

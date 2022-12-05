#!/bin/bash
plurl=$(cat plurl.txt)
outputDir='music'
ytopts=('--cookies-from-browser' 'firefox' '--download-archive' "$outputDir/archive.txt" '-x' '--recode-video' 'mp3' '--embed-metadata' '--embed-thumbnail' '--fixup' 'warn' '--sponsorblock-remove' 'all' "-o" "$outputDir/%(title)s [%(id)s].%(ext)s")

# check dependencies are available
if ! (type rg && type yt-dlp && type fd && type basename && type awk) > /dev/null
then
	echo "Missing dependencies"
	exit 1
fi

# check that outputDir exists in filesystem
if [ ! -d "$outputDir" ]
then
	echo "Output directory does not exist"
	exit 1
fi

function download() {
	# download playlist
	yt-dlp "${ytopts[@]}" "$@"
}
log=$(download "$plurl" 2>&1)
# print log to stdout
echo "$log" > yt-dlp.log
# yt-dlp fails for some videos because they are only on youtube music. see https://github.com/yt-dlp/yt-dlp/issues/723
echo "$log" | rg 'Video unavailable. This video is not available'


# if a id is in archive but not in the playlist, remove it
plids=$(yt-dlp --flat-playlist --get-id "$plurl")
while read -r line
do
	id=$(echo "$line" | cut -d' ' -f2)
	if ! echo "$plids" | rg -qF -- "$id"
	then
		fd -t f -F -x rm -v \; -- "$id" "$outputDir" 
		echo "Removing $id from archive"
		# sed -i "/$id/d" "$outputDir/archive.txt"
		awk -i inplace -vId="$id" '!index($0,Id)' "$outputDir/archive.txt"
	fi
done < $outputDir/archive.txt

# if a file is in the folder but not in the archive, remove it
while read -r file
do
	if ! rg -qF -- "$(basename "$file" | rg -o '\[(.{11})\]\..{3}' -r '$1')" $outputDir/archive.txt
	then
		rm -v "$file"
	fi
done < <(fd -t f -E archive.txt . "$outputDir")

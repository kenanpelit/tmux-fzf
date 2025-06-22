#!/usr/bin/env bash
FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --header='Select clipboard history. Press TAB to mark multiple items.'"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/.envs"

# -----------------------------
# Pano Yönetimi
# -----------------------------
# Supports both copyq and cliphist
# exec-once = wl-paste --type text --watch cliphist store

# Determine action
if [ -z "$1" ]; then
	action="system"
else
	action="$1"
fi

if [[ "$action" == "system" ]]; then
	# Check which clipboard manager is available
	if [ -x "$(command -v cliphist)" ]; then
		# Cliphist implementation (original working code)
		selected_item=$(cliphist list | eval "$TMUX_FZF_BIN $TMUX_FZF_OPTIONS")
		[[ -z "$selected_item" ]] && exit
		echo "$selected_item" | cliphist decode | xargs -I{} sh -c 'tmux set-buffer -b *temp*tmux_fzf "{}" && tmux paste-buffer -b *temp*tmux_fzf && tmux delete-buffer -b *temp*tmux_fzf'
	elif [ -x "$(command -v copyq)" ]; then
		# CopyQ implementation
		item_numbers=$(copyq count)
		contents="[cancel]\n"
		index=0
		while [ "$index" -lt "$item_numbers" ]; do
			_content="$(copyq read ${index} | tr '\n' ' ' | tr '\\n' ' ')"
			contents="${contents}copy${index}: ${_content}\n"
			index=$((index + 1))
		done
		copyq_index=$(printf "$contents" | eval "$TMUX_FZF_BIN $TMUX_FZF_OPTIONS --preview=\"echo {} | sed -e 's/^copy//' -e 's/: .*//' | xargs -I{} copyq read {}\"" | sed -e 's/^copy//' -e 's/: .*//')
		[[ "$copyq_index" == "[cancel]" || -z "$copyq_index" ]] && exit
		echo "$copyq_index" | xargs -I{} sh -c 'tmux set-buffer -b *temp*tmux_fzf "$(copyq read {})" && tmux paste-buffer -b *temp*tmux_fzf && tmux delete-buffer -b *temp*tmux_fzf'
	else
		# No clipboard manager available, fallback to buffer mode
		echo "No supported clipboard manager found (copyq or cliphist). Using tmux buffer mode." >&2
		action="buffer"
	fi
fi

if [[ "$action" == "buffer" ]]; then
	# Tmux buffer implementation (original working code)
	selected_buffer=$(tmux list-buffers | sed -e 's/:.*bytes//' -e '1s/^/[cancel]\n/' -e 's/: "/: /' -e 's/"$//' | eval "$TMUX_FZF_BIN $TMUX_FZF_OPTIONS --preview=\"echo {} | sed -e 's/\[cancel\]//' -e 's/:.*$//' | head -1 | xargs tmux show-buffer -b\"" | sed 's/:.*$//')
	[[ "$selected_buffer" == "[cancel]" || -z "$selected_buffer" ]] && exit
	echo "$selected_buffer" | xargs -I{} sh -c 'tmux paste-buffer -b {}'
fi

# Print out Memory, cpu and load using https://github.com/thewtex/tmux-mem-cpu-load

run_segment() {
	type tmux-mem-cpu-load >/dev/null 2>&1
	if [ "$?" -ne 0 ]; then
		return
	fi

	stats=$(tmux-mem-cpu-load -q -a 1 -g 0 -m 0 -i 2)
	if [ -n "$stats" ]; then
		echo "$stats #[fg=#434c5e]#[bg=#434c5e] ";
	fi
	return 0
}

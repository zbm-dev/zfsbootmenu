#! /bin/bash

## This load-key hook provides a nicer passphrase prompt
## to the user, showing the number of characters typed in
## as '*'.
##
## We use this instead of `whiptail` or `dialog` so we
## can actually just include this hook using the
## zbm.hookroot commandline on a standard EFI download.
## printf, stty, test, and head are all in coreutils.
##
## To use, find the mountable reference of your EFI
## System Partition, then put this file into a
## `hooks/load-key.d/` directory in your ESP, and run
## the following command to modify the ZFSBootMenu
## commandline:
##
##     zbm-kcl -r zbm.hookroot -a zbm.hookroot=${ESP_NAME}//${ESP_PATH}/hooks ${ZFSBOOTMENU_EFI}

# Switch to altscreen.
printf '\e[?1049h' > /dev/tty

OPENED=no
while [ $OPENED '!=' yes ]; do
	printf '\e[2mEnter passphrase for '\''\e[0m\e[1m%s\e[0m\e[2m'\'': \e[0m' "$ZBM_LOCKED_FS" > /dev/tty

	OLD_TTY="$(stty -g)"
	stty raw -echo

	PASSWORD=''
	DONE=no
	while [ $DONE '!=' yes ]; do
		CHAR="$(head -q -c 1 /dev/tty 2> /dev/null)"

		# In raw mode, <enter> translates to \r,
		# not \n
		if [ "$CHAR" '=' $'\n' ] || [ "$CHAR" '=' $'\r' ] || [ "$CHAR" '=' '' ]; then
			DONE=yes

		# \177 is DEL key; many terminals translate
		# backspace to DEL in raw mode.
		elif [ "$CHAR" '=' $'\b' ] || [ "$CHAR" '=' $'\177' ]; then
			if [ "$PASSWORD" '!=' '' ]; then
				printf '\b \b' > /dev/tty
				PASSWORD=${PASSWORD/%?/}
			fi

		# Ignore other control characters.
		elif [ "$CHAR" '<' ' ' ]; then
			# Ignore
			:

		# Presumably a normal character.
		else
			printf '\e[4m*\e[0m' > /dev/tty
			PASSWORD="$PASSWORD$CHAR"
		fi
	done
	stty "$OLD_TTY"

	# Clear screen.
	# The `clear` command is technically not in coreutils,
	# but in `ncurses-bin`.
	printf '\e[2J\e[3J\r' > /dev/tty

	echo "$PASSWORD" | zfs load-key -L prompt "$ZBM_ENCRYPTION_ROOT" > /dev/null 2>&1
	EXIT_CODE=$?
	if [ $EXIT_CODE '=' 0 ]; then
		OPENED=yes
	else
		printf '\e[31mPassphrase incorrect.\e[0m\n' > /dev/tty
	fi
done

# Exit altscreen
printf '\e[?1049l' > /dev/tty

exit 0

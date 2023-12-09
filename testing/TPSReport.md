# TPS Report: Test Procedure Specification for ZFSBootMenu Release

The following list of quality checks for ZFSBootMenu should be performed on at
least two separate test environments. If possible, checks should be performed
against all supported testing environments. An initial environment can be
prepared by invoking, from `testing/`, a command like

    ./setup.sh -a -e -k -o <distro>

The `-e` flag is optional but will produce an encrypted pool with passphrase
"zfsbootmenu". By default, the `org.zfsbootmenu:keysource` property will be set
to the first boot environment configured on a pool image, which allows
ZFSBootMenu to cache keys for pools it unlocks. Testing with an encrypted pool
is recommended; all code paths encountered by an unencrypted pool should also
be hit with encrypted pools, but an encrypted pool will trigger additional code
paths that should be exercised.

The `-k` flag is also optional. It will populate the `testing/keys` directory
with your SSH `authorized_keys` file and create host keys that will be
installed in every BE to simplify SSH logins. After the `testing/keys`
directory is created, `-k` need not be specified again.

During setup, the ZFSBootMenu master branch will be cloned into `/zfsbootmenu`
within the boot environment; this environment will be used to generate a kernel
and initramfs pair in `/zfsbootmenu/build` that will be copied into the test
directory for use in the testing procedure. The newly generated images will
overwrite any existing ZBM kernel and initramfs.

Additional testbeds can be set up independently by passing the `-D <directory>`
option to the above `setup.sh` command. Alternatively, a distinct environment
can be installed on a separate pool within the same testbed by using a command
like

    ./setup.sh -i -e -p <pool-name> -o <distro>

where `<pool-name>` is a name distinct from any other pool currently present in
the testbed (the default pool name is `ztest`, but numeric components may be
appended [01, 02, etc.] to distinguish a pool from another
currently imported pool. Again, the `-e` flag is optional.

It is also possible to add a distinct boot environment to an existing pool,
using a command like

    ./setup.sh -i -x -p <pool-name> -o <distro>

where the `-x` indicates that an existing pool will be used. The option
`-p <pool-name>` is not needed if the default `ztest` pool is desired and
present. At most one BE per supported distro may be installed on a pool,
because each BE is placed at

    <pool-name>/ROOT/<distro>

For testing, a mix of multiple pools and multiple BEs on a single pool are
recommended.

Once an environment is prepared, it can be run with

    ./run -i

The `-D <directory>` argument may be provided to launch an environment in a
non-standard directory. The `-i` option is optional; it causes the directory
`${HOME}/.ssh/zfsbootmenu.d` to be created with mode 700. If this directory
exists (or is created with `-i`), `run.sh` will create a host configuration at
the path

    ${HOME}/.ssh/zfsbootmenu.d/${TESTHOST}

where `${TESTHOST}` is the basename of the test environment directory, with the
text `test.` prepended if the path does not already begin with `test.`. The
configuration enables SSH logins into the test environment simply by typing

    ssh ${TESTHOST}

The configuration will log into the root account of the testbed and bypasses
any host key verification or storage. When the test environment terminates, the
configuration file will be removed. To make use of these configurations, be
sure to add

    Include zfsbootmenu.d/*

to your `${HOME}/.ssh/config`. Once the `${HOME}/.ssh/zfsbootmenu.d` path
exists, it is not necessary to specify the `-i` option to continue to use
automatic host configuration.

ZFSBootMenu is configured by default to force the menu to appear. At least
once, test the ZFSBootMenu countdown timer and automatic boot procedure with

    ./run -A zbm.timeout=10

This should cause a 10-second countdown to appear before the default boot
environment is booted. The default boot environment is the last environment
installed in a test environment.

## Main Menu Checks

From the main menu, perform the following checks:

- [ ] Pressing `[RETURN]` on an arbitrary BE causes that environment to boot.

- [ ] Pressing `[ESCAPE]` causes the screen to redraw.

- [ ] Pressing `[CTRL+P]` displays status for the pool holding the currently
  selected boot environment.

- [ ] Pressing `[CTRL+D]` on an arbitrary BE causes its pool to be re-imported
  read/write, changing the display header to red and moving that BE to the top
  of the menu; after rebooting, this BE should be selected by default and
  should automatically boot when the timer is activated.

- [ ] Pressing `[CTRL+S]` displays the list of snapshots on the currently
  selected BE.

- [ ] Pressing `[CTRL+K]` displays the list of bootable kernels installed in the
  currently selected BE.

- [ ] Pressing `[CTRL+E]` displays the KCL edit screen, pre-populating the
  entry field with the existing KCL; changing the entry should alter the KCL
  dsplayed in the header and these changes should appear in `/proc/cmdline` in
  the next booted BE.

- [ ] Pressing `[CTRL+J]` jumps into an interactive chroot for the selected BE,
  which will be read-only if the pool is mounted read-only and read/write
  otherwise. If the pool is read-only, exiting the chroot should cause a yellow
  `[!]` warning icon to appear in the header.

- [ ] Pressing `[CTRL+R]` exits ZFSBootMenu and drops to a recovery shell.
  Exiting the recovery shell restarts ZFSBootMenu.

- [ ] Pressing `[CTRL+W]` toggles the pool holding the selected BE between
  read-only and read/write.

- [ ] Pressing `[CTRL+O]` cycles through name/creation/used sort order.

## Pool Status Checks

- [ ] Pressing `[CTRL+R]` causes a checkpoint rewind; this should be a no-op if
  the pool has not been checkpointed. Otherwise, any snapshots created after a
  checkpoint should disappear after the rewind.

- [ ] Pressing `[ESCAPE]` returns to the main menu.

## Snapshot List Checks

- [ ] Pressing `[CTRL+J]` jumps into an interactive chroot for the selected
  snapshot, or fails if the snapshot is missing a shell.

- [ ] Pressing `[CTRL+D]` shows the diff viewer:
    - Selecting one snapshot will show a diff between the snapshot and the filesystem
    - Selecting two snapshots will show the diff between them
    - The diff screen updates dynamically and is interruptable
    - After exiting the diff screen, the same snapshots will be selected

- [ ] Pressing `[RETURN]` presents the snapshot duplication interface:
    - The new name is prepopulated with `_NEW` appended to the old name
    - An existing environment with the same name triggers additional user input
    - Blanking the name and pressing `[RETURN]` aborts the duplication
    - Entering a non-empty name triggers a duplicate
    - The duplicate BE appears in the list of bootable environments
    - Neither the original nor the duplicate show a new ORIGIN property

- [ ] Pressing `[CTRL+X]` behaves as with `[RETURN]`, except:
    - Cloning does not trigger a buffered send-receive and is faster
    - The ORIGIN property of the original BE will list the selected snapshot on
      the newly cloned BE

- [ ] Pressing `[CTRL+C]` behaves as with `[RETURN]`, except:
    - Cloning does not trigger a buffered send-receive and is faster
    - The ORIGIN property of the cloned BE will list the selected snapshot on
      the original BE

- [ ] Pressing `[CTRL+N]` presents the snapshot creation interface:
    - The new snapshot name is prepopulated with %Y-%m-%d-%H%M%S
    - An existing snapshot with the same name triggers additional user input
    - Blanking the name and pressing `[RETURN]` aborts the snapshot
    - Entering a non-empty name triggers a new snapshot
    - The new snapshot appears in the list of snapshots

- [ ] Pressing `[CTRl+R]` presents the rollback creation prompt:
    - The selected snapshot is listed, highlighted in red
    - Entering anything but `ROLLBACK` cancels the operation
    - Entering `ROLLBACK` rolls the dataset back to the snapshot
    - The selected snapshot is no longer listed on the Snapshot screen

- [ ] Pressing `[CTRL+O]` cycles through name/creation/used sort order.

- [ ] Pressing `[ESCAPE]` returns to the main menu.

## Kernel List Checks

At least one BE should include multiple kernels to confirm proper functionality
of the kernel list. That BE should be selected when entering the list.

- [ ] Pressing `[RETURN]` will boot the selected kernel within the selected BE.

- [ ] Pressing `[CTRL+D]` changes the default kernel, setting the property
  `org.zfsbootmenu:kernel` on the BE to the selected kernel name, returning to
  the main menu with the selected kernel listed in the header. A subsequent
  reboot should use the selected kernel without further user interaction.

- [ ] Pressing `[CTRL+U]` clears the default kernel by inheriting the
  `org.zfsbootmenu:kernel` parameter from the BE parent.

- [ ] Pressing `[ESCAPE]` returns to the main menu.

## Common Features

- [ ] Pressing `[CTRL+L]` displays the log viewer, which should be blank unless
  a warning or error `[!]` indicator has previously appeared in the header.

- [ ] Pressing `[CTRL+H]` displays the help browser, preselecting the section
  corresponding to the current menu screen.

- [ ] Pressing the left/right arrow keys moves to the next/previous screen shown
  in the header. Screens will not wrap around.

- [ ] When booting a test VM with GTK output and efifb, the font will be resized
  to change the apparent resolution of the console. Successful font changes are
  logged via `zinfo()`.

## General Testing

- [ ] If every encryption root specifies an `org.zfsbootmenu:keysource`
  property and a `file://` key location, toggling pools between read-only and
  read/write should proceed without requesting passwords.

- [ ] If any encryption root specifices an `org.zfsbootmenu:keysource`
  property and a `file` key location, keys should appear under the path

      /zfsbootmenu/.keys/<keysource>/<keylocation>

  where `<keysource>` is the value of an `org.zfsbootmenu:keysource` property
  on an encryption root and and `<keylocation>` is its key location.

- [ ] If any encryption root lacks an `org.zfsbootmenu:keysource` property,
  toggling its pool between read-only and read/write should force a passphrase
  prompt each time. (Keys must not have been already cached before a keysource
  property is cleared, or the previously cached keys will continue to be used.)

- [ ] ZBM can be forced to spin until the pool defined via `zbm.prefer=pool!`
  is available. During the wait period, the user can exit to a recovery shell
  via `[ESCAPE]`.

- [ ] ZBM can be forced to import the pool defined via `zbm.prefer=pool!!` with
  all other pools ignored/skipped. This will spin until the pool is available, and
  can be broken via `[ESCAPE]`.

- [ ] Invalid `spl_hostid` or `spl.spl_hostid` values do not cause ZBM to fail.

- [ ] Adding `zbm.skip` to the KCL causes ZBM to immediately boot BOOTFS,
  otherwise show the main menu.

- [ ] Adding `zbm.show` to the KCL causes ZBM to always show the main menu.

- [ ] Adding `rd.vconsole.keymap=fr` causes the ZBM keymap to change when booted
  in GTK mode. This can be verified by dropping to the recovery shell and typing
  qwerty.

- [ ] User hooks are installed from `$zfsbootmenu_hook_root` as defined in the
  dracut or mkinitcpio configuration used by `generate-zbm`.

- [ ] Any hooks installed in a ZFSBootMenu image execute at expected points.

- [ ] Installed hooks cam be properly skipped by specifying their names in the
  `zbm.skip_hooks` kernel command-line parameter.

## Recovery Shell and SSH Access

- [ ] Basic tab completion for some internal functions is available in the
  recovery shell.

- [ ] SSH'ing in to dracut-crypt enabled ZBM build should result in a functional
  shell, with a proper path and prompt set.

- [ ] A running copy of ZBM can be taken over from a remote session:

    - Executing `zbm` or `zfsbootmenu` from the remote login will attempt to
      stop any currently running instance.

    - Until the running instance is stopped, the new invocation will spin with
      a timed message until it succeeds or the user cancels the attempt.

- [ ] In the recovery shell, in a recovery image, verify networking:
    - `dhclient` should successfully configure a network interface.
    - `curl` should successfully retrieve https://get.zfsboot.menu/efi
    - `mbuffer -I 1234` should start and listen on port 1234, accepting traffic

## OS-Specific Image Creation

- [ ] For each supported distribution [Void, Void Musl, Arch, Ubuntu, Debian],
  verify that `module-setup.sh` is able to correctly install all required
  binaries in the initramfs.

- [ ] For each supported distribution, verify that `generate-zbm` can successfully
  produce an versioned and unversioned initramfs and a unified EFI bundle.

- [ ] For each supported distribution, verify that the components and EFI bundles
  are able to correctly boot other systems. The check stages listed above should
  be used and any functionality that is missing or broken noted.

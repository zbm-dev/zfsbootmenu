Snapshot Management
===================

Keyboard Shortcuts
------------------

*[ENTER]* **duplicate**

  Creation method: *zfs send | zfs recv*

  This creates a boot environment that does not depend on any other snapshots, allowing it to be destroyed at will. The new boot environment will immediately consume space on the pool equal to the *REFER* value of the snapshot.

  A duplicated boot environment is commonly used if you need a new boot environment without any associated snapshots.

  The operation will fail gracefully if the pool can not be set *read/write*.

  If *mbuffer* is available, it is used to provide feedback.

*[MOD+X]* **clone and promote**

  Creation method: *zfs clone , zfs promote*

  This creates a boot environment that is not dependent on the origin snapshot, allowing you to destroy the file system that the clone was created from. A cloned and promoted boot environment is commonly used when you've done an upgrade but want to preserve historical snapshots.

  The operation will fail gracefully if the pool can not be set *read/write*.

*[MOD+C]* **clone**

  Creation method: *zfs clone*

  This creates a boot environment from a snapshot with out modifying snapshot inheritence. A cloned boot environment is commonly used if you need to boot a previous system state for a short time and then discard the environment.

  The operation will fail gracefully if the pool can not be set *read/write*.

*[MOD+N]* **snapshot creation**

  This creates a new snapshot of the currently selected boot environment. A new snapshot is useful if you need to repair a boot environment from a chroot, to allow for easy roll-back of the changes.

  The operation will fail gracefully if the pool can not be set *read/write*.

*[MOD+D]* **diff**

  Compare the differences between snapshots and filesystems. A single snapshot can be selected and a diff will be generated between that and the current state of the filesystem. Two snapshots can be selected (and deselected) with the tab key and a diff will be generated between them.

  The operation will fail gracefully if the pool can not be set *read/write*.

*[MOD+J]* **jump into chroot**

  Enter a chroot of the selected boot environment snapshot. The snapshot is always mounted read-only.

*[MOD+O]* **sort order**

  Cycle the sorting key through the following list:

  * **name** Use the filesystem or snapshot name
  * **creation** Use the filesystem or snapshot creation time
  * **used** Use the filesystem or snapshot size

  The default sort key is *name*.

*[MOD+L]* **view logs**

  View logs, as indicated by *[!]*. The indicator will be yellow for warning conditions and red for errors.

*[MOD+R]* **roll back snapshot**

  Roll back a boot environment to the selected snapshot. This is a destructive operation that will not proceed without affirmative confirmation.

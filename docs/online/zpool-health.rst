ZPOOL Health
============

Keyboard Shortcuts
------------------

*[MOD+R]* **rewind checkpoint**

  If a pool checkpoint is available, the selected pool is exported and then imported with the *--rewind-to-checkpoint* flag set.

  The operation will fail gracefully if the pool can not be set *read/write*.

*[MOD+L]* **view logs**

  View logs, as indicated by *[!]*. The indicator will be yellow for warning conditions and red for errors.

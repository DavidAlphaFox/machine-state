(in-package #:org.shirakumo.machine-state)

(docs:define-docs
  (type query-failed
    "Error signalled if a query should fail for some reason.

This condition is *NOT* signalled if the function is simply
unsupported. It is however signalled if an OS call failed for some
reason such as lack of access permissions.")
  
  (function process-io-bytes
    "Returns the number of bytes of IO performed by the process.

Returns three values:
  The total number of IO bytes performed.
  The bytes read.
  The bytes written.

IO in this context refers to any activity to external devices such as
drives, networking, etc.

If the function is unsupported a constant 0 is returned for all
values.

See STORAGE-IO-BYTES
See NETWORK-IO-BYTES")
  
  (function process-time
    "Returns the amount of processing time spent by this process in seconds.

This does not include time spent in the kernel.

If the function is unsupported a constant 0.0d0 is returned.

See MACHINE-TIME
See THREAD-TIME
See GC-TIME
See GPU-TIME")
  
  (function process-room
    "Returns the process' memory usage statistics.

This includes foreign memory usage.

Returns the number of bytes occupied.

If the function is unsupported a constant 0 is returned.

See MACHINE-ROOM
See GC-ROOM
See GPU-ROOM
See STATIC-ROOM
See STACK-ROOM
See STORAGE-ROOM")
  
  (function machine-room
    "Returns the machine's primary memory usage statistics.

Returns two values:
  The number of physical bytes occupied
  The total number of physical bytes available

If the function is unsupported a constant 0 is returned for all
values.

See PROCESS-ROOM
See GC-ROOM
See GPU-ROOM
See STATIC-ROOM
See STACK-ROOM
See STORAGE-ROOM")

  (function machine-cores
    "Returns the number of cores available on the machine.

If the function is unsupported a constant 1 is returned.

See THREAD-CORE-MASK")

  (function machine-uptime
    "Returns the number of seconds since the machine was started up.

If the function is unsupported a constant 0 is returned.")

  (function machine-time
    "Returns the amount of time spent processing.

Core may be T for an aggregate of all cores, or an integer of the core number.

Returns two values:
  The time spent idle in seconds
  The total time spent in seconds

If the function is unsupported a constant 0.0d0 is returned.

See MACHINE-CORES")
  
  (function thread-time
    "Returns the amount of processing time spent by this thread in seconds.

This does not include time spent in the kernel.

Thread may be T for the current thread, or a BT:THREAD.

If the function is unsupported a constant 0.0d0 is returned.

See MACHINE-TIME
See PROCESS-TIME
See GC-TIME
See GPU-TIME")

  (function thread-core-mask
    "Accessor to the CPU core affinity mask of the thread.

The mask is a bitfield where each set bit in the integer designates a
core that the thread may be executed on. For compatibility reasons
only integers up to 64 bits are supported.

Thread may be T for the current thread, or a BT:THREAD.

If the function is unsupported a constant of all 1s is returned.

When setting this place, the *actual* affinity mask of the thread is
returned, which may differ from the one you tried to set.

See MACHINE-CORES")

  (function process-priority
    "Accessor to the scheduler priority of the process.

The priority can be one of the following values, in ascending order of
importance:

  :IDLE
  :LOW
  :NORMAL
  :HIGH
  :REALTIME

If the function is unsupported :NORMAL is returned in all cases.

When setting this place, the *actual* priority of the process is
returned, which may differ from the one you tried to set.

See THREAD-PRIORITY")

  (function thread-priority
    "Accessor to the scheduler priority of the thread.

The priority can be one of the following values, in ascending order of
importance:

  :IDLE
  :LOW
  :NORMAL
  :HIGH
  :REALTIME

Thread may be T for the current thread, or a BT:THREAD.

If the function is unsupported :NORMAL is returned in all cases.

When setting this place, the *actual* priority of the thread is
returned, which may differ from the one you tried to set.

See PROCESS-PRIORITY")

  (function gc-room
    "Returns the GC's memory usage statistics.

This does not include foreign memory usage.

Returns two values:
  The number of free bytes
  The total number of bytes available

If the function is unsupported a constant 0 is returned for both
values.

See MACHINE-ROOM
See PROCESS-ROOM
See GPU-ROOM
See STATIC-ROOM
See STACK-ROOM
See STORAGE-ROOM")
  
  (function gc-time
    "Returns the amount of processing time spent in the GC.

If the function is unsupported a constant 0.0d0 is returned.

See MACHINE-TIME
See PROCESS-TIME
See GC-TIME
See GPU-TIME
See THREAD-TIME")
  
  (function gpu-room
    "Returns the GPU's memory usage statistics.

Returns two values:
  The number of free bytes
  The total number of bytes available

If the function is unsupported a constant 0 is returned for both
values.

You may want to load the machine-state/opengl library to make this
function useful. In that case, it will only work if an OpenGL context
is current to this thread.

See MACHINE-ROOM
See PROCESS-ROOM
See GC-ROOM
See STATIC-ROOM
See STACK-ROOM
See STORAGE-ROOM")
  
  (function gpu-time
    "Returns the amount of processing time spent on the GPU by this process.

If the function is unsupported a constant 0.0d0 is returned.

You may want to load the machine-state/opengl library to make this
function useful. In that case, it will only work if an OpenGL context
is current to this thread.

See PROCESS-TIME
See GC-TIME
See MACHINE-TIME
See THREAD-TIME")
  
  (function static-room
    "Returns the static space size as an integer.

If the function is unsupported zero is returned.

See MACHINE-ROOM
See PROCESS-ROOM
See GC-ROOM
See GPU-ROOM
See STACK-ROOM
See STORAGE-ROOM")
  
  (function stack-room
    "Return the stack usage statistics.

Returns two values:
  The number of free stack bytes
  The total stack space available

See MACHINE-ROOM
See PROCESS-ROOM
See GC-ROOM
See GPU-ROOM
See STATIC-ROOM
See STORAGE-ROOM")

  (function storage-room
    "Return file system storage usage statistics.

The argument may either be a pathname to a file on the device to
query, or the system provided name for the device.

Returns two values:
  The number of free bytes
  The total number of bytes available

See STORAGE-DEVICE
See STORAGE-DEVICE-PATH
See MACHINE-ROOM
See PROCESS-ROOM
See GC-ROOM
See GPU-ROOM
See STATIC-ROOM
See STACK-ROOM")

  (function storage-device
    "Return the system device name of the device backing the path.

Returns the device name as a string if it can be found and signals a
QUERY-FAILED error otherwise.

See STORAGE-DEVICE-PATH
See STORAGE-ROOM
See STORAGE-IO-BYTES")

  (function storage-device-path
    "Return a path which the storage device is backing if any.

Returns the path as a directory pathname if it can be found and
signals a QUERY-FAILED error otherwise.

See STORAGE-DEVICE
See STORAGE-ROOM
See STORAGE-IO-BYTES")

  (function storage-io-bytes
    "Returns the number of bytes of IO performed on the storage device.

The argument may either be a pathname to a file on the device to
query, the system provided name for the device, or T to get an
aggregate of all attached devices.

Returns three values:
  The total number of IO bytes performed.
  The bytes read.
  The bytes written.

If the function is unsupported a constant 0 is returned.

See STORAGE-DEVICE
See STORAGE-DEVICE-PATH
See NETWORK-IO-BYTES
See PROCESS-IO-BYTES")

  (function network-devices
    "Returns a list of network device names.

If the function is unsupported an empty list is returned.

See NETWORK-IO-BYTES")

  (function network-io-bytes
    "Returns the number of bytes of IO performed on the network device.

The argument may either be the system name of the device as a string
or T to get an aggregate of all attached devices.

Returns three values:
  The total number of IO bytes performed.
  The bytes read.
  The bytes written.

If the function is unsupported a constant 0 is returned.

See NETWORK-DEVICES
See PROCESS-IO-BYTES
See STORAGE-IO-BYTES"))

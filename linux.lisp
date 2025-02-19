(in-package #:org.shirakumo.machine-state)

(defmacro with-proc ((file &rest fields) &body body)
  `(cffi:with-foreign-object (io :char 2048)
     (let ((file (cffi:foreign-funcall "fopen" :string ,file :string "rb" :pointer)))
       (when (cffi:null-pointer-p file)
         (fail (cffi:foreign-funcall "strerror" :int64 errno)))
       (cffi:foreign-funcall "fread" :pointer io :size 1 :size 2048 :pointer file :size)
       (cffi:foreign-funcall "fclose" :pointer file :void))
     (let ,(loop for (var field) in fields
                 collect `(,var (let* ((field ,field)
                                       (start (cffi:foreign-funcall "strstr" :pointer io :string field :pointer))
                                       (ptr (cffi:inc-pointer start (length field))))
                                  (cffi:foreign-funcall "atol" :pointer ptr :long))))
       ,@body)))

(defmacro do-proc (vars (file fgetsspec &optional return) &body body)
  `(cffi:with-foreign-objects ((io :char 2048)
                               ,@vars)
     (let ((file (cffi:foreign-funcall "fopen" :string ,file :string "rb" :pointer)))
       (when (cffi:null-pointer-p file)
         (fail (cffi:foreign-funcall "strerror" :int64 errno)))
       (unwind-protect 
            (loop while (/= 0 (cffi:foreign-funcall "fgets" :pointer io :size 2048 :pointer file :int))
                  do (when (= ,(length vars) (cffi:foreign-funcall "sscanf" :pointer io :string ,fgetsspec
                                                                   ,@(loop for (name) in vars collect :pointer collect name)
                                                                   :int))
                       ,@body)
                  finally (progn (return ,return)))
         (cffi:foreign-funcall "fclose" :pointer file :void)))))

(define-implementation process-io-bytes ()
  (with-proc ("/proc/self/io" (read "rchar: ") (write "wchar: "))
    (values (+ read write) read write)))

;;;; For whatever reason on Linux rusage is useless for this, so redefine it here.
(define-implementation process-room ()
  (with-proc ("/proc/self/smaps_rollup" (rss "Rss: "))
    (* 1024 rss)))

(define-implementation machine-time (core)
  (let ((scale (/ (float (posix-call "sysconf" :int 2 :long) 0d0))))
    (flet ((conv (x) (* x scale)))
      (etypecase core
        ((eql T)
         (with-proc ("/proc/stat" (user "cpu  ") (nice " ") (system " ") (idle " "))
           (values (conv idle) (conv (+ user nice system idle)))))
        (integer
         (with-proc ("/proc/stat" (user (format NIL "cpu~d " core)) (nice " ") (system " ") (idle " "))
           (values (conv idle) (conv (+ user nice system idle)))))))))

(cffi:defcstruct (stat :size 144 :conc-name stat-)
  (dev     :uint64 :offset  0))

(define-implementation storage-device (path)
  (cffi:with-foreign-objects ((stat '(:struct stat)))
    (when (< (cffi:foreign-funcall "stat" :string (pathname-utils:native-namestring path) :pointer stat :int) 0)
      (fail (cffi:foreign-funcall "strerror" :int64 errno)))
    (let ((dev (stat-dev stat)))
      (do-proc ((l :int) (r :int) (name :char 32))
          ("/proc/self/mountinfo" "%*d %*d %d:%d / %*s %*s %*s - %*s /dev/%s"
                                  (fail "Device not found in mountinfo table"))
        (when (and (= (cffi:mem-ref l :int) (ldb (byte 32 8) dev))
                   (= (cffi:mem-ref r :int) (1- (ldb (byte 8 0) dev))))
          (return (cffi:foreign-string-to-lisp name :max-chars 32)))))))

(define-implementation storage-device-path (device)
  (do-proc ((mount :char 512) (name :char 32))
      ("/proc/self/mountinfo" "%*d %*d %*d:%*d / %s %*s %*s - %*s /dev/%s"
                              (fail "Device not found in mountinfo table"))
    (when (= 0 (cffi:foreign-funcall "strncmp" :pointer name :string device :size 32 :int))
      (return (pathname-utils:parse-native-namestring
               (cffi:foreign-string-to-lisp mount :max-chars 32)
               :as :directory)))))

(cffi:defcstruct (statvfs :size 112 :conc-name statvfs-)
  (bsize    :uint64 :offset  0)
  (frsize   :uint64 :offset  8)
  (blocks   :uint64 :offset 16)
  (bfree    :uint64 :offset 24)
  (bavail   :uint64 :offset 32)
  (files    :uint64 :offset 40)
  (ffree    :uint64 :offset 48)
  (favail   :uint64 :offset 56)
  (fsid     :uint64 :offset 64)
  (flag     :uint64 :offset 72)
  (namemax  :uint64 :offset 80))

(define-implementation storage-room (path)
  (when (stringp path)
    (setf path (storage-device-path path)))
  (cffi:with-foreign-objects ((statvfs '(:struct statvfs)))
    (posix-call "statvfs" :string (pathname-utils:native-namestring path) :pointer statvfs :int)
    (values (* (statvfs-bavail statvfs)
               (statvfs-bsize statvfs))
            (* (statvfs-blocks statvfs)
               (statvfs-bsize statvfs)))))

(define-implementation storage-io-bytes (device)
  (when (pathnamep device)
    (setf device (storage-device device)))
  (cffi:with-foreign-objects ((lasttop :char 32))
    (setf (cffi:mem-aref lasttop :char 0) 1)
    (etypecase device
      ((eql T)
       (let ((read 0) (write 0))
         (do-proc ((name :char 32)
              (reads :unsigned-long-long)
              (writes :unsigned-long-long))
             ("/proc/diskstats" "%*d %*d %31s %*u %*u %llu %*u %*u %*u %llu"
                                (values (* 512 (+ read write))
                                        (* 512 read)
                                        (* 512 write)))
           (when (/= 0 (cffi:foreign-funcall "strncmp" :pointer lasttop :pointer name :size (cffi:foreign-funcall "strlen" :pointer lasttop :size) :int))
             (cffi:foreign-funcall "strncpy" :pointer lasttop :pointer name :size 32)
             (incf read (cffi:mem-ref reads :unsigned-long-long))
             (incf write (cffi:mem-ref writes :unsigned-long-long))))))
      (string
       (do-proc ((name :char 32)
                 (reads :unsigned-long-long)
                 (writes :unsigned-long-long))
           ("/proc/diskstats" "%*d %*d %31s %*u %*u %llu %*u %*u %*u %llu" (fail "No such device."))
         (when (= 0 (cffi:foreign-funcall "strncmp" :pointer name :string device :size 32 :int))
           (return (values (* 512 (+ (cffi:mem-ref reads :unsigned-long-long)
                                     (cffi:mem-ref writes :unsigned-long-long)))
                           (* 512 (cffi:mem-ref reads :unsigned-long-long))
                           (* 512 (cffi:mem-ref writes :unsigned-long-long))))))))))

(define-implementation network-devices ()
  (let ((list ()))
    (do-proc ((name :char 32))
        ("/proc/net/dev" "%31s" (cddr (nreverse list)))
      (push (cffi:foreign-string-to-lisp name :count (1- (cffi:foreign-funcall "strlen" :pointer name :size))) list))))

(define-implementation network-io-bytes (device)
  (etypecase device
    ((eql T)
     (let ((read 0) (write 0))
       (do-proc ((name :char 32)
                 (reads :unsigned-long-long)
                 (writes :unsigned-long-long))
           ("/proc/net/dev" "%31s %llu %*u %*u %*u %*u %*u %*u %*u %llu %*u"
                            (values (+ read write) read write))
         (unless (= 0 (cffi:foreign-funcall "strncmp" :pointer name :string "lo:" :size 32 :int))
           (incf read (cffi:mem-ref reads :unsigned-long-long))
           (incf write (cffi:mem-ref writes :unsigned-long-long))))))
    (string
     (do-proc ((name :char 32)
               (reads :unsigned-long-long)
               (writes :unsigned-long-long))
         ("/proc/net/dev" "%31s %llu %*u %*u %*u %*u %*u %*u %*u %llu %*u"
                          (fail "No such device."))
       (when (= 0 (cffi:foreign-funcall "strncmp" :pointer name :string device :size (1- (length device)) :int))
         (return (values (+ (cffi:mem-ref reads :unsigned-long-long)
                            (cffi:mem-ref writes :unsigned-long-long))
                         (cffi:mem-ref reads :unsigned-long-long)
                         (cffi:mem-ref writes :unsigned-long-long))))))))

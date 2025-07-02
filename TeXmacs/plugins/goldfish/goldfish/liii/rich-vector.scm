;
; Copyright (C) 2025 The Goldfish Scheme Authors
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
; http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
; WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
; License for the specific language governing permissions and limitations
; under the License.
;

(define-library (liii rich-vector)
(import (liii string) (liii hash-table) (liii sort) (liii list) (liii vector) (liii oop) (srfi srfi-8))
(export rich-vector)
(begin

(define-case-class rich-vector ((data vector?))

(define (@range start end . step)
  (let ((step-size (if (null? step) 1 (car step))))
    (cond
      ((and (positive? step-size) (>= start end))
       (rich-vector #()))
      ((and (negative? step-size) (<= start end))
       (rich-vector #()))
      ((zero? step-size)
       (value-error "Step size cannot be zero"))
      (else
       (let ((cnt (ceiling (/ (- end start) step-size))))
         (rich-vector (list->vector (iota cnt start step-size))))))))

(define (@empty . args)
  (chain-apply args
    (rich-vector #())))

(define (@fill n elem . args)
  (unless (integer? n)
    (type-error "n must be integer" n))
  (when (< n 0)
    (value-error "n must be non-negative" n))
  (chain-apply args
    (rich-vector (make-vector n elem))))

(define (%collect) data)

(define (%length)
  (vector-length data))

(define (%size)
  (vector-length data))

(define (%apply i)
  (when (or (< i 0) (>= i (vector-length data)))
    (index-error "rich-vector%apply: out of range with index" i))
  (vector-ref data i))

(define (%index-of x)
  (or (vector-index (lambda (y) (class=? x y)) data)
      -1))

(define (%last-index-of x)
  (or (vector-index-right (lambda (y) (class=? x y)) data)
      -1))

(define (%find p)
  (let loop ((i 0))
    (cond
     ((>= i (vector-length data)) (none))
     ((p (vector-ref data i)) (option (vector-ref data i)))
     (else (loop (+ i 1))))))

(define (%find-last pred)
  (let loop ((i (- (vector-length data) 1)))
    (cond
      ((< i 0) (none))  ; 遍历完所有元素未找到
      ((pred (vector-ref data i)) (option (vector-ref data i)))  ; 找到符合条件的元素
      (else (loop (- i 1))))))  ; 继续向前查找

(define (%head)
  (if (> (vector-length data) 0)
      (vector-ref data 0)
      (error 'out-of-range "out-of-range")))

(define (%head-option)
  (if (> (vector-length data) 0)
      (option (vector-ref data 0))
      (none)))

(define (%last)
  (let ((len (vector-length data)))
    (if (> len 0)
      (vector-ref data (- len 1))
      (index-error "rich-vector%last: empty vector"))))

(define (%last-option)
  (let ((len (vector-length data)))
    (if (> len 0)
      (option (vector-ref data (- len 1)))
      (none))))

(define (%slice from until . args)
  (chain-apply args
    (let* ((len (vector-length data))
           (start (max 0 from))
           (end (min len until)))
      (if (< start end)
          (rich-vector (vector-copy data start end))
          (rich-vector :empty)))))

(define (%empty?)
  (= (length data) 0))

(define (%equals that)
  (and (that :is-instance-of 'rich-vector)
       (vector= class=? data (that 'data))))

(define (%forall p)
  (vector-every p data))

(define (%exists p)
  (vector-any p data))

(define (%contains elem)
  (%exists (lambda (x) (equal? x elem))))

(define (%map x . args)
  (chain-apply args
    (rich-vector (vector-map x data))))

(define (%flat-map f . args)
  (chain-apply args
    (rich-vector (%map f :reduce vector-append))))

(define (%filter x . args)
  (chain-apply args
    (rich-vector (vector-filter x data))))

(define (%for-each x)
  (vector-for-each x data))

(define (%reverse . args)
  (chain-apply args
    (rich-vector (reverse data))))

(define (%count . xs)
  (cond ((null? xs) (vector-length data))
        ((length=? 1 xs) (count (car xs) (vector->list data)))
        (else (error 'wrong-number-of-args "rich-vector%count" xs))))

(define (%take n . args)
  (define (scala-take data n)
    (cond
      ((< n 0) (vector))
      ((>= n (vector-length data)) data)
      (else
        (let ((new-vec (make-vector n)))
          (do ((i 0 (+ i 1)))
              ((>= i n) new-vec)
            (vector-set! new-vec i (vector-ref data i)))))))
  
  (chain-apply args
    (rich-vector (scala-take data n))))

(define (%take-right n . args)
  (define (scala-take-right data n)
    (let ((len (vector-length data)))
      (cond
        ((< n 0) (vector))
        ((>= n len) data)
        (else
          (let ((new-vec (make-vector n)))
            (do ((i (- len n) (+ i 1))
                 (j 0 (+ j 1)))
                ((>= j n) new-vec)
              (vector-set! new-vec j (vector-ref data i))))))))

  (chain-apply args
    (rich-vector (scala-take-right data n))))

(define (%drop n . args)
  (define (scala-drop data n)
    (cond
      ((< n 0) data)
      ((>= n (vector-length data)) (vector))
      (else (vector-copy data n))))
  (chain-apply args
    (rich-vector (scala-drop data n))))

(define (%drop-right n . args)
  (define (scala-drop-right data n)
    (cond
      ((< n 0) data)
      ((>= n (vector-length data)) (vector))
      (else (vector-copy data 0 (- (vector-length data) n)))))
  
  (chain-apply args
    (rich-vector (scala-drop-right data n))))

(define (%drop-while pred . args)
  (chain-apply args
    (let ((len (vector-length data)))
      (let loop ((i 0))
        (cond
          ((>= i len) (rich-vector :empty))  ; 所有元素都被丢弃
          ((pred (vector-ref data i)) (loop (+ i 1)))  ; 继续丢弃
          (else (rich-vector (vector-copy data i)))))))) ; 返回剩余部分

(define (%fold initial f)
  (vector-fold f initial data))

(define (%fold-right initial f)
  (vector-fold-right f initial data))

(define (%count . xs)
  (cond ((null? xs) (vector-length data))
        ((length=? 1 xs) (count (car xs) (vector->list data)))
        (else (error 'wrong-number-of-args "rich-vector%count" xs))))

(define (%sort-with less-p . args)
  (chain-apply args
    (rich-vector (vector-stable-sort less-p data))))

(define (%sort-by f . args)
  (chain-apply args
    (let ((sorted-data (vector-stable-sort (lambda (x y) (< (f x) (f y))) data)))
      (rich-vector sorted-data))))

(define (%group-by func)
  (let ((group (make-hash-table)))
    (for-each
      (lambda (elem) 
        (let ((key (func elem)))
          (hash-table-update!/default
            group
            key
            (lambda (current-list) (cons elem current-list))
            '())))
      (vector->list data))
    (hash-table-for-each 
      (lambda (k v) (hash-table-set! group k (reverse-list->vector v))) 
      group)
    (rich-hash-table group)))

(define (%sliding size . step-arg)
  (unless (integer? size) (type-error "rich-vector%sliding: size must be an integer " size))
  (unless (> size 0) (value-error "rich-vector%sliding: size must be a positive integer " size))

  (let ((N (vector-length data)))
    (if (zero? N)
        #()
        (let* ((is-single-arg-case (null? step-arg))
               (step (if is-single-arg-case 1 (car step-arg))))

          ;; Validate step if provided
          (when (and (not is-single-arg-case)
                     (or (not (integer? step)) (<= step 0)))
            (if (not (integer? step))
                (type-error "rich-vector%sliding: step must be an integer " step)
                (value-error "rich-vector%sliding: step must be a positive integer " step)))
          
          ;; single-argument version when N < size
          (if (and is-single-arg-case (< N size))
              (vector data)
              (let collect-windows ((current-idx 0) (result-windows '()))
                (cond
                  ;; Stop if current_idx is out of bounds
                  ((>= current-idx N) (list->vector (reverse result-windows)))
                  ;; For single-arg case
                  ((and is-single-arg-case (> (+ current-idx size) N))
                   (list->vector (reverse result-windows)))
                  (else
                   (let* ((window-end (if is-single-arg-case
                                          (+ current-idx size)      ;; Single-arg: always takes full 'size'
                                          (min (+ current-idx size) N))) ;; Two-arg: can be partial
                          (current-window (vector-copy data current-idx window-end)))
                     (collect-windows (+ current-idx step) (cons current-window result-windows)))))))))))

(define (%zip-with-index . args)
  (chain-apply args
    (let* ((n (vector-length data))
           (result (make-vector n)))
      (let loop ((idx 0))
        (if (>= idx n)
            (rich-vector result)
            (begin
              (vector-set! 
                  result 
                  idx 
                  (cons idx (vector-ref data idx)))
              (loop (+ idx 1))))))))

(define (%distinct . args)
  (chain-apply args
    (let ((ht (make-hash-table))
          (length (vector-length data)))
      (let loop ((result '())
                (index 0))
        (if (>= index length)
            (rich-vector (list->vector (reverse result)))
            (let ((elem (vector-ref data index)))
              (if (eq? (hash-table-ref ht elem) #f)
                  (begin
                    (hash-table-set! ht elem #t)
                    (loop (cons elem result) (+ index 1)))
                   (loop result (+ index 1)))))))))

(define (%reduce f)
  (let ((len (vector-length data)))
    (if (zero? len)
        (value-error "rich-vector%reduce: empty vector is not allowed to reduce")
        (let loop ((acc (vector-ref data 0))
                   (i 1))
          (if (>= i len)
              acc
              (loop (f acc (vector-ref data i)) (+ i 1)))))))

(define (%index-where pred)
  (or (vector-index pred data)
      -1))

(define (%last-index-where pred)
  (or (vector-index-right pred data)
      -1))

(define (%take-while pred . args)
  (chain-apply args
    (let* ((vec data)
           (len (vector-length vec))
           (idx (vector-index (lambda (x) (not (pred x))) vec)))
      (rich-vector (vector-copy vec 0 (or idx len))))))

(define (%max-by f)
  (when (not (procedure? f))
    (type-error "rich-vector%max-by: f must be a procedure"))
  
  (let ((vec data)
        (len (length data)))
    (if (zero? len)
        (value-error "rich-vector%max-by: empty list is not allowed")
        (let loop ((i 1)
                   (max-elem (vector-ref vec 0))
                   (max-val (f (vector-ref vec 0))))
          (if (>= i len)
              max-elem
              (let* ((current-elem (vector-ref vec i))
                     (current-val (f current-elem)))
                (unless (number? current-val)
                  (type-error "f must return a number"))
                (if (< current-val max-val)
                    (loop (+ i 1) max-elem max-val)
                    (loop (+ i 1) current-elem current-val))))))))

(define (%min-by f)
  (when (not (procedure? f))
    (type-error "rich-vector%min-by: f must be a procedure"))

  (let ((vec data)
        (len (length data)))
    (if (zero? len)
        (value-error "rich-vector%min-by: empty list is not allowed")
        (let loop ((i 1)
                   (min-elem (vector-ref vec 0))
                   (min-val (f (vector-ref vec 0))))
          (if (>= i len)
              min-elem
              (let* ((current-elem (vector-ref vec i))
                     (current-val (f current-elem)))
                (unless (number? current-val)
                  (type-error "f must return a number"))
                (if (> current-val min-val)
                    (loop (+ i 1) min-elem min-val)
                    (loop (+ i 1) current-elem current-val))))))))

(define (%max-by-option f)
  (when (not (procedure? f))
    (type-error "rich-vector%max-by-option: f must be a procedure"))

  (if (zero? (vector-length data))
      (none)
      (option (%max-by f))))

(define (%min-by-option f)
  (when (not (procedure? f))
    (type-error "rich-vector%min-by-option: f must be a procedure"))

  (if (zero? (vector-length data))
      (none)
      (option (%min-by f))))

(define (%to-string)
  ((%map object->string)
   :make-string "#(" " " ")"))

(define (%make-string . xs)
  (define (parse-args xs)
    (cond
      ((null? xs) (values "" "" ""))
      ((length=? 1 xs)
       (let ((sep (car xs)))
         (if (string? sep)
             (values "" sep "")
             (type-error "rich-vector%make-string: separator must be a string" sep))))
      ((length=? 2 xs)
       (error 'wrong-number-of-args "rich-vector%make-string: expected 0, 1, or 3 arguments, but got 2" xs))
      ((length=? 3 xs)
       (let ((start (car xs))
             (sep (cadr xs))
             (end (caddr xs)))
         (if (and (string? start) (string? sep) (string? end))
             (values start sep end)
             (type-error "rich-vector%make-string: prefix, separator, and suffix must be strings" xs))))
      (else (error 'wrong-number-of-args "rich-vector%make-string: expected 0, 1, or 3 arguments" xs))))

  (receive (start sep end) (parse-args xs)
    (let* ((as-string (lambda (x) (if (string? x) x (object->string x))))
           (middle (string-join (map as-string (vector->list data)) sep)))
      (string-append start middle end))))

(define (%to-list)
  (vector->list data))

(define (%to-rich-list)
  (rich-list (vector->list data)))

(define (%set! i x)
  (when (or (< i 0) (>= i (length data)))
    (index-error "rich-vector%set! out of range at index" i))
  (vector-set! data i x))

(define (%append v)
  (when (not (or (vector? v) (rich-vector :is-type-of v)))
    (type-error "rich-vector%append: input is not vector or rich-vector"))
  
  (if (vector? v)
      (rich-vector (vector-append data v))
      (rich-vector (vector-append data (v :collect)))))

) ; end of define-case-class

) ; end of begin
) ; end of define-library

;;; SRFI-1 list-processing library                      -*- Scheme -*-
;;; Reference implementation
;;;
;;; SPDX-License-Identifier: MIT
;;;
;;; Copyright (c) 1998, 1999 by Olin Shivers. You may do as you please with
;;; this code as long as you do not remove this copyright notice or
;;; hold me liable for its use. Please send bug reports to shivers@ai.mit.edu.
;;;     -Olin
;;;
;;; Copyright (c) 2024 The Goldfish Scheme Authors
;;; Follow the same License as the original one

(define-library (srfi srfi-1)
(import (liii error)
        (liii base))
(export
  ; SRFI 1: Constructors
  circular-list iota list-copy xcons cons*
  ; SRFI 1: Predicates
  circular-list? null-list? proper-list? dotted-list?
  ; SRFI 1: Selectors
  first second third fourth fifth
  sixth seventh eighth ninth tenth
  take drop take-right drop-right fold fold-right split-at
  reduce reduce-right append-map filter partition remove find
  delete delete-duplicates
  ; SRFI 1: Miscellaneous: length, append, concatenate, reverse, zip & count
  zip count
  ; SRFI 1: Association List
  assoc assq assv alist-cons
  take-while drop-while list-index any every
  last-pair last)
(begin

(define (xcons a b)
         (cons b a))

(define (cons* a . b)
  (if (null? b)
      a
      (cons a (apply cons* b))))

; 0 clause BSD, from S7 repo stuff.scm
(define* (iota count (start 0) (step 1))
  (when (not (integer? count))
    (type-error "iota: count must be an integer"))
  (when (< count 0)
    (value-error "iota: count must be non-negative but received ~d" count))
  (do ((i count (- i 1))
       (val (+ start (* (- count 1) step)) (- val step))
       (result '() (cons val result)))
      ((zero? i) result)))

(define (proper-list? x)
  (let loop ((x x) (lag x))
    (if (pair? x)
        (let ((x (cdr x)))
          (if (pair? x)
              (let ((x   (cdr x))
                    (lag (cdr lag)))
                (and (not (eq? x lag)) (loop x lag)))
              (null? x)))
        (null? x))))

(define (dotted-list? x)
  (let loop ((x x) (lag x))
    (if (pair? x)
        (let ((x (cdr x)))
          (if (pair? x)
              (let ((x   (cdr x))
                    (lag (cdr lag)))
                (and (not (eq? x lag)) (loop x lag)))
              (not (null? x))))
        (not (null? x)))))

(define (null-list? l)
  (cond ((pair? l) #f)
        ((null? l) #t)
        (else
         (error 'wrong-type-arg "null-list?: argument out of domain" l))))

(define first car)

(define second cadr)

(define third caddr)

(define (fourth x) (list-ref x 3))

(define (fifth x) (list-ref x 4))

(define (sixth x) (list-ref x 5))

(define (seventh x) (list-ref x 6))

(define (eighth x) (list-ref x 7))

(define (ninth x) (list-ref x 8))

(define (tenth x) (list-ref x 9))

(define (take l k)
  (let loop ((l l) (k k))
    (if (zero? k)
        '()
        (cons (car l)
              (loop (cdr l) (- k 1))))))

(define drop list-tail)

(define (take-right l k)
  (let loop ((lag l)
             (lead (drop l k)))
    (if (pair? lead)
        (loop (cdr lag) (cdr lead))
        lag)))

(define (drop-right l k)
  (let loop ((lag l) (lead (drop l k)))
    (if (pair? lead)
        (cons (car lag) (loop (cdr lag) (cdr lead)))
        '())))

(define (split-at lst i)
  (when (< i 0)
    (value-error "require a index greater than 0, but got ~A -- split-at" i))
  (let ((result (cons #f '())))
    (do ((j i (- j 1))
         (rest lst (cdr rest))
         (node result (cdr node)))
        ((zero? j)
         (values (cdr result) rest))
      (when (not (pair? rest))
        (value-error "lst length cannot be greater than i, where lst is ~A, but i is ~A-- split-at" lst i))
      (set-cdr! node (cons (car rest) '())))))


(define (last-pair l)
  (if (pair? (cdr l))
      (last-pair (cdr l))
      l))

(define (last l)
  (car (last-pair l)))

(define (count pred list1 . lists)
  (let lp ((lis list1) (i 0))
    (if (null-list? lis) i
        (lp (cdr lis) (if (pred (car lis)) (+ i 1) i)))))

(define (zip . lists)
  (apply map list lists))

(define (fold f initial . lists)
  (unless (procedure? f)
    (error 'type-error "expected procedure, got ~S" f))
  
  (cond
    ((null? lists) initial)
    
    ((and (pair? lists) (null? (cdr lists)) (list? (car lists)))
     (let loop ((acc initial) (lst (car lists)))
       (if (null? lst)
           acc
           (loop (f (car lst) acc) (cdr lst)))))
    
    (else
     (let loop ((acc initial) (lsts lists))
       (if (any null? lsts)
           acc
           (let* ((cars (map car lsts))
                  (cdrs (map cdr lsts)))
             (loop (apply f (append cars (list acc))) cdrs)))))))

(define (fold-right f initial . lists)
  (unless (procedure? f)
    (error 'type-error "expected procedure, got ~S" f))
  
  (cond
    ((null? lists) initial)
    ((and (pair? lists) (null? (cdr lists)) (list? (car lists)))
     (let loop ((lst (car lists)))
       (if (null? lst)
           initial
           (f (car lst) (loop (cdr lst))))))
    (else
     (let loop ((lsts lists))
       (if (any null? lsts)
           initial
           (let* ((cars (map car lsts))
                  (cdrs (map cdr lsts)))
             (apply f (append cars (list (loop cdrs))))))))))

(define (reduce f initial l)
  (if (null-list? l) initial
      (fold f (car l) (cdr l))))

(define (reduce-right f initial l)
  (if (null-list? l) initial
      (let recur ((head (car l)) (l (cdr l)))
        (if (pair? l)
            (f head (recur (car l) (cdr l)))
            head))))

(define (append-map proc . lists)
  (unless (procedure? proc)
    (error 'type-error "expected procedure, got ~S" proc))
  (for-each 
    (lambda (lst)
      (unless (list? lst)
        (error 'type-error "expected list, got ~S" lst)))
    lists)
  (apply append (apply map proc lists)))

(define (filter pred l)
  (let recur ((l l))
    (if (null-list? l) l
        (let ((head (car l))
              (tail (cdr l)))
          (if (pred head)
              (let ((new-tail (recur tail)))
                (if (eq? tail new-tail) l
                    (cons head new-tail)))
              (recur tail))))))

(define (partition pred l)
  (let loop ((lst l) (satisfies '()) (dissatisfies '()))
    (cond ((null? lst)
           (cons satisfies dissatisfies))
          ((pred (car lst))
           (loop (cdr lst) (cons (car lst) satisfies) dissatisfies))
          (else
           (loop (cdr lst) satisfies (cons (car lst) dissatisfies))))))

(define (remove pred l)
  (filter (lambda (x) (not (pred x))) l))

(define (find pred l)
  (cond ((null? l) #f)
        ((pred (car l)) (car l)) 
        (else (find pred (cdr l)))))

(define (take-while pred lst)
  (if (null? lst) 
      '()
      (if (pred (car lst))
          (cons (car lst) (take-while pred (cdr lst)))
          '())))

(define (drop-while pred l)
  (if (null? l)
      '()
      (if (pred (car l))
          (drop-while pred (cdr l))
          l)))

(define (list-index pred l)
    (let loop ((index 0) (l l))
      (if (null? l)
          #f
          (if (pred (car l))
              index
              (loop (+ index 1) (cdr l))))))

(define (any pred? l)
  (cond ((null? l) #f)
        ((pred? (car l)) #t)
        (else (any pred? (cdr l)))))

(define (every pred? l)
  (cond ((null? l) #t)
        ((not (pred? (car l))) #f)
        (else (every pred? (cdr l)))))

(define (%extract-maybe-equal maybe-equal)
  (let ((my-equal (if (null-list? maybe-equal)
                      equal?
                      (car maybe-equal))))
    (if (procedure? my-equal)
        my-equal
        (error 'wrong-type-arg "maybe-equal must be procedure"))))

(define (delete x l . maybe-equal)
  (let ((my-equal (%extract-maybe-equal maybe-equal)))
    (filter (lambda (y) (not (my-equal x y))) l)))

;; Check if equality function is supported by s7 hash-table
(define (%can-use-hash-table? eq-func)
  (memq eq-func '(eq? eqv? equal? equivalent? = string=? string-ci=? char=? char-ci=?)))

;; Fast hash-table based deduplication using s7's native hash-table
(define (%delete-duplicates-hash lis eq-func)
  (let ((seen (make-hash-table 8 eq-func))
        (result '()))
    (for-each 
      (lambda (x)
        (unless (hash-table-ref seen x)
          (hash-table-set! seen x #t)
          (set! result (cons x result))))
      lis)
    (reverse result)))

;; origin
(define (%delete-duplicates-scan lis my-equal)
  (let loop ((remaining lis) (seen '()) (result '()))
    (cond
      ((null? remaining)
       (reverse result))
      ((member (car remaining) seen my-equal)
       (loop (cdr remaining) seen result))
      (else
       (loop (cdr remaining)
             (cons (car remaining) seen)
             (cons (car remaining) result))))))

;;; right-duplicate deletion
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; delete-duplicates delete-duplicates!
;;;
;;; Hybrid strategy: Use hash table O(n) for supported functions and 
;;; optimized scan O(n²) for other functions
;;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(define (delete-duplicates lis . maybe-equal)
  (let ((my-equal (%extract-maybe-equal maybe-equal)))
    (cond
      ((null? lis) lis)
      ((%can-use-hash-table? my-equal)
       (%delete-duplicates-hash lis my-equal))
      (else
       (%delete-duplicates-scan lis my-equal)))))

(define (alist-cons key value alist)
  (cons (cons key value) alist))

(define (circular-list val1 . vals)
  (let ((ans (cons val1 vals)))
    (set-cdr! (last-pair ans) ans)
    ans))

(define (circular-list? x)
  (let loop ((x x) (lag x))
    (and (pair? x)
         (let ((x (cdr x)))
           (and (pair? x)
                (let ((x   (cdr x))
                      (lag (cdr lag)))
                  (or (eq? x lag) (loop x lag))))))))

) ; end of begin
) ; end of define-library


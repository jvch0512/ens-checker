(import (chicken base) (chicken io) (chicken string) (chicken file) (chicken process-context) (chicken time) (chicken condition) (chicken format))
(include "ens.scm")

(define (usage)
  (display "usage: ens-checker PATH [--tsv] [--fail-on medium|high|critical] [--today YYYY-MM-DD]\nExit: 0 ok, 1 findings at or above --fail-on, 2 bad input.\n" (current-error-port))
  (exit 2))

(define (read-all p)
  (condition-case (call-with-input-file p (lambda (port) (let ((s (read-string #f port))) (if (eof-object? s) "" s))))
    ((exn) "")))

(define (ends-with? s suf)
  (let ((n (string-length s)) (m (string-length suf)))
    (and (>= n m) (string=? (substring s (- n m) n) suf))))

(define (pad s n) (if (< (string-length s) n) (pad (string-append s " ") n) s))

(define (strip-slash p) (if (and (> (string-length p) 1) (ends-with? p "/")) (strip-slash (substring p 0 (- (string-length p) 1))) p))

(define (basename p)
  (let loop ((i (- (string-length p) 1)))
    (cond ((< i 0) p) ((char=? (string-ref p i) #\/) (substring p (+ i 1) (string-length p))) (else (loop (- i 1))))))

(define (main args)
  (let loop ((a args) (path #f) (tsv #f) (fail #f) (today (quotient (current-seconds) 86400)))
    (cond
      ((null? a) (run (or path (usage)) tsv fail today))
      ((string=? (car a) "--tsv") (loop (cdr a) path #t fail today))
      ((string=? (car a) "--fail-on")
       (if (and (pair? (cdr a)) (member (cadr a) '("medium" "high" "critical")))
           (loop (cddr a) path tsv (cadr a) today)
           (usage)))
      ((string=? (car a) "--today")
       (let ((d (and (pair? (cdr a)) (parse-date (cadr a)))))
         (if d (loop (cddr a) path tsv fail d) (usage))))
      ((char=? (string-ref (car a) 0) #\-) (usage))
      (path (usage))
      (else (loop (cdr a) (car a) tsv fail today)))))

(define (run path tsv fail today)
  (unless (or (file-exists? path) (directory-exists? path))
    (display (string-append "error: no such file or directory: " path "\n") (current-error-port))
    (exit 2))
  (let* ((files (if (directory-exists? path)
                    (let ((base (strip-slash path)))
                      (map (lambda (n) (cons n (string-append base "/" n)))
                           (sort (filter (lambda (n) (ends-with? n ".facts")) (directory base)) string<?)))
                    (list (cons (basename path) path))))
         (all (sort-findings (apply append (map (lambda (f) (audit (read-all (cdr f)) (car f) today)) files))))
         (head (string-append (number->string (length files)) " files, " (number->string (length all)) " findings")))
    (display (if tsv (string-append "# " head) head)) (newline)
    (for-each
     (lambda (f)
       (if tsv
           (begin (display (string-append (f-sev f) "\t" (f-rule f) "\t" (f-where f) "\t" (f-msg f))) (newline))
           (begin (display (string-append (pad (upper (f-sev f)) 8) " " (f-rule f) " " (f-where f))) (newline)
                  (display (string-append "         " (f-msg f))) (newline))))
     all)
    (if (and fail (any-at-or-above all (rank fail))) (exit 1) (exit 0))))

(define (any-at-or-above l r)
  (cond ((null? l) #f) ((<= (rank (f-sev (car l))) r) #t) (else (any-at-or-above (cdr l) r))))

(main (command-line-arguments))

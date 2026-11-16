(import (chicken base) (chicken string) (chicken sort) (chicken format))
(include "src/ens.scm")

(define passed 0)
(define failed 0)
(define (check ok name)
  (if ok (set! passed (+ passed 1))
      (begin (set! failed (+ failed 1)) (display (string-append "FAIL: " name "\n")))))

(define today (parse-date "2026-11-16"))
(define (rules text) (map f-rule (audit text "t.facts" today)))
(define (rules-str text) (let loop ((l (rules text)) (acc "")) (if (null? l) acc (loop (cdr l) (string-append acc (if (string=? acc "") "" ",") (car l))))))

(define (facts cat0 . over)
  (define cat (or cat0 ""))
  ;; a fully compliant fact set for CAT, with OVER pairs replacing or adding keys
  (let* ((base (list (cons "category" cat) (cons "password_min_length" "14") (cons "mfa_admin" "yes")
                     (cons "log_retention_days" "400") (cons "patch_max_age_days" "10") (cons "disk_encryption" "yes")
                     (cons "tls_min_version" "1.3") (cons "backup_frequency_days" "1") (cons "admin_accounts_shared" "no")
                     (cons "risk_analysis_date" "2026-09-15") (cons "incident_register" "yes") (cons "time_sync" "yes")))
         (merged (let loop ((o over) (b base))
                   (if (null? o) b
                       (loop (cdr o) (append (filter (lambda (p) (not (string=? (car p) (car (car o))))) b)
                                             (if (cdr (car o)) (list (car o)) '())))))))
    (let loop ((l merged) (s ""))
      (if (null? l) s (loop (cdr l) (string-append s (car (car l)) ": " (cdr (car l)) "\n"))))))

(check (string=? (rules-str (facts "ALTA")) "") "compliant ALTA")
(check (string=? (rules-str (facts "MEDIA")) "") "compliant MEDIA")
(check (string=? (rules-str (facts "BASICA")) "") "compliant BASICA")

;; thresholds per category
(check (string=? (rules-str (facts "BASICA" (cons "password_min_length" "7"))) "ENS001") "pwd 7 BASICA")
(check (string=? (rules-str (facts "BASICA" (cons "password_min_length" "8"))) "") "pwd 8 BASICA")
(check (string=? (rules-str (facts "MEDIA" (cons "password_min_length" "11"))) "ENS001") "pwd 11 MEDIA")
(check (string=? (rules-str (facts "MEDIA" (cons "password_min_length" "12"))) "") "pwd 12 MEDIA")
(check (string=? (rules-str (facts "ALTA" (cons "password_min_length" "13"))) "ENS001") "pwd 13 ALTA")
(check (string=? (rules-str (facts "BASICA" (cons "log_retention_days" "89"))) "ENS003") "logs 89 BASICA")
(check (string=? (rules-str (facts "MEDIA" (cons "log_retention_days" "179"))) "ENS003") "logs 179 MEDIA")
(check (string=? (rules-str (facts "MEDIA" (cons "log_retention_days" "180"))) "") "logs 180 MEDIA")
(check (string=? (rules-str (facts "ALTA" (cons "log_retention_days" "364"))) "ENS003") "logs 364 ALTA")
(check (string=? (rules-str (facts "BASICA" (cons "patch_max_age_days" "91"))) "ENS004") "patch 91 BASICA")
(check (string=? (rules-str (facts "MEDIA" (cons "patch_max_age_days" "31"))) "ENS004") "patch 31 MEDIA")
(check (string=? (rules-str (facts "ALTA" (cons "patch_max_age_days" "16"))) "ENS004") "patch 16 ALTA")
(check (string=? (rules-str (facts "ALTA" (cons "patch_max_age_days" "15"))) "") "patch 15 ALTA")
(check (string=? (rules-str (facts "BASICA" (cons "backup_frequency_days" "8"))) "ENS007") "backup 8 BASICA")
(check (string=? (rules-str (facts "BASICA" (cons "backup_frequency_days" "7"))) "") "backup 7 BASICA")
(check (string=? (rules-str (facts "MEDIA" (cons "backup_frequency_days" "2"))) "ENS007") "backup 2 MEDIA")

;; boolean rules and severity
(check (string=? (rules-str (facts "MEDIA" (cons "mfa_admin" "no"))) "ENS002") "no mfa MEDIA")
(check (string=? (f-sev (car (audit (facts "MEDIA" (cons "mfa_admin" "no")) "t" today))) "high") "mfa high in MEDIA")
(check (string=? (f-sev (car (audit (facts "BASICA" (cons "mfa_admin" "no")) "t" today))) "medium") "mfa medium in BASICA")
(check (string=? (rules-str (facts "BASICA" (cons "disk_encryption" "no"))) "") "disk encryption not required in BASICA")
(check (string=? (rules-str (facts "MEDIA" (cons "disk_encryption" "no"))) "ENS005") "disk encryption required in MEDIA")
(check (string=? (rules-str (facts "BASICA" (cons "incident_register" "no"))) "") "incident register not required in BASICA")
(check (string=? (rules-str (facts "ALTA" (cons "incident_register" "no"))) "ENS010") "incident register required in ALTA")
(check (string=? (rules-str (facts "ALTA" (cons "admin_accounts_shared" "yes"))) "ENS008") "shared admins")
(check (string=? (rules-str (facts "ALTA" (cons "time_sync" "no"))) "ENS011") "no time sync")
(check (string=? (rules-str (facts "ALTA" (cons "tls_min_version" "1.1"))) "ENS006") "tls 1.1")
(check (string=? (rules-str (facts "ALTA" (cons "tls_min_version" "1.2"))) "") "tls 1.2")
(check (string=? (rules-str (facts "ALTA" (cons "tls_min_version" "1.0"))) "ENS006") "tls 1.0")
(check (string=? (rules-str (facts "ALTA" (cons "mfa_admin" "YES"))) "") "yes is case-insensitive")
(check (string=? (rules-str (facts "ALTA" (cons "mfa_admin" "true"))) "") "true accepted")

;; dates
(check (string=? (rules-str (facts "ALTA" (cons "risk_analysis_date" "2025-11-16"))) "") "exactly 365 days is fine")
(check (string=? (rules-str (facts "ALTA" (cons "risk_analysis_date" "2025-11-15"))) "ENS009") "366 days is old")
(check (string=? (rules-str (facts "ALTA" (cons "risk_analysis_date" "soon"))) "ENS009") "invalid date")
(check (string=? (rules-str (facts "ALTA" (cons "risk_analysis_date" #f))) "ENS009") "missing date")
(check (= (dayno 1970 1 1) 0) "epoch")
(check (= (- (dayno 2000 3 1) (dayno 2000 2 28)) 2) "leap 2000")
(check (= (- (dayno 1900 3 1) (dayno 1900 2 28)) 1) "1900 not leap")
(check (not (parse-date "2026-13-01")) "month 13")
(check (not (parse-date "26-1-1")) "short date")
(check (parse-date " 2026-11-16 ") "spaces trimmed")

;; missing facts
(check (string=? (rules-str (facts "ALTA" (cons "password_min_length" #f))) "ENS001") "missing password length")
(check (string=? (rules-str (facts "ALTA" (cons "log_retention_days" "many"))) "ENS003") "non numeric retention")
(check (string=? (rules-str (facts "ALTA" (cons "tls_min_version" #f))) "ENS006") "missing tls")
(check (string=? (rules-str (facts "ALTA" (cons "mfa_admin" #f))) "ENS002") "missing mfa")

;; category handling
(check (member "ENS000" (rules (facts "ULTRA"))) "unknown category reported")
(check (member "ENS000" (rules (facts #f))) "empty category reported")
(check (string=? (f-sev (car (audit (facts "ULTRA") "t" today))) "info") "ENS000 is info")
(check (string=? (rules-str (facts "media")) "") "category lowercase accepted")

;; parsing
(check (string=? (rules-str "") "ENS000") "empty file")
(check (string=? (rules-str "\n\n# only comments\n") "ENS000") "only comments")
(check (= (length (parse-facts "a: 1\n# c\n\nb : 2 \nnocolon\n: x\n")) 2) "parse skips junk")
(check (string=? (fval (car (parse-facts "Key:   spaced value  \n"))) "spaced value") "value trimmed")
(check (string=? (car (car (parse-facts "KEY: 1\n"))) "key") "keys lowercased")
(check (= (fline (cadr (parse-facts "a: 1\nb: 2\n"))) 2) "line numbers")
(check (string=? (rules-str (string-append (facts "ALTA") "\r\n")) "") "crlf tolerated")
(check (let ((r (audit (facts "ALTA" (cons "mfa_admin" "no")) "x.facts" today))) (let ((w (f-where (car r)))) (and (> (string-length w) 8) (string=? (substring w 0 8) "x.facts:")))) "where with line")
(check (let ((r (audit (facts "ALTA" (cons "risk_analysis_date" #f)) "x.facts" today))) (string=? (f-where (car r)) "x.facts")) "where without line")

;; sorting
(let ((s (sort-findings (list (finding "low" "B" "a" 1 "") (finding "high" "A" "z" 9 "") (finding "high" "A" "a" 10 "") (finding "high" "A" "a" 2 "")))))
  (check (equal? (map (lambda (f) (list (f-file f) (f-line f))) s) '(("a" 2) ("a" 10) ("z" 9) ("a" 1))) "severity, file, numeric line"))

;; fuzz with a deterministic generator
(define seed 12345)
(define (rnd n) (set! seed (modulo (+ (* seed 1103515245) 12345) 2147483648)) (modulo (quotient seed 65536) n))
(define bits (vector "" ":" "\n" "category" "MEDIA" "mfa_admin" "yes" " " "\r" "#" "risk_analysis_date" "2026-01-01" "tls_min_version" "1.2" "999999999999999999999" "-5"))
(define (gen n) (if (= n 0) "" (string-append (vector-ref bits (rnd (vector-length bits))) (gen (- n 1)))))
(define crashed #f)
(let loop ((i 0))
  (when (< i 3000)
    (handle-exceptions exn (set! crashed #t) (audit (gen (+ 1 (rnd 30))) "f" today))
    (loop (+ i 1))))
(check (not crashed) "3000 random inputs do not raise")

(display (string-append (number->string passed) " passed, " (number->string failed) " failed\n"))
(exit (if (= failed 0) 0 1))

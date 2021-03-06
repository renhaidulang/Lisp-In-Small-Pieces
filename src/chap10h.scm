;;; $Id: chap10h.scm,v 4.1 2006/11/25 17:44:43 queinnec Exp $

;;;(((((((((((((((((((((((((((((((( L i S P ))))))))))))))))))))))))))))))))
;;; This file is derived from the files that accompany the book:
;;;     LISP Implantation Semantique Programmation (InterEditions, France)
;;;     or  Lisp In Small Pieces (Cambridge University Press).
;;; By Christian Queinnec <Christian.Queinnec@INRIA.fr>
;;; The original sources can be downloaded from the author's website at
;;;   http://pagesperso-systeme.lip6.fr/Christian.Queinnec/WWW/LiSP.html
;;; This file may have been altered from the original in order to work with
;;; modern schemes. The latest copy of these altered sources can be found at
;;;   https://github.com/appleby/Lisp-In-Small-Pieces
;;; If you want to report a bug in this program, open a GitHub Issue at the
;;; repo mentioned above.
;;; Check the README file before using this file.
;;;(((((((((((((((((((((((((((((((( L i S P ))))))))))))))))))))))))))))))))

;;;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;;; Define an initial environment with the predefined primitives. Only
;;; those that have a fixed number of arguments appear. Since direct
;;; calls are emitted to them only if they have a fixed arity.

(define-syntax defprimitive
  (syntax-rules ()
    ((defprimitive name Cname arity)
     (let ((v (make-Predefined-Variable 
               'name (make-Functional-Description 
                      = arity 
                      (make-predefined-application-generator 
                       'Cname ) ) )))
       (set! g.init (cons v g.init))
       'name ) ) ) )

(defprimitive cons "SCM_cons" 2)
(defprimitive car "SCM_car" 1)
(defprimitive cdr "SCM_cdr" 1)
(defprimitive set-car! "SCM_set_car" 2)
(defprimitive set-cdr! "SCM_set_cdr" 2)
(defprimitive pair? "SCM_pairp" 1)
(defprimitive null? "SCM_nullp" 1)
(defprimitive symbol? "SCM_symbolp" 1)
(defprimitive stringp "SCM_stringp" 1)
(defprimitive eq? "SCM_eqp" 2)
(defprimitive integer? "SCM_fixnump" 1)
(defprimitive procedure? "SCM_procedurep" 1)

;;; Use macros instead of calling functions. 

(defprimitive + "SCM_Plus" 2)
(defprimitive - "SCM_Minus" 2)
(defprimitive * "SCM_Times" 2)
(defprimitive / "SCM_Quotient" 2)
(defprimitive remainder "SCM_Remainder" 2)
(defprimitive <= "SCM_LeP" 2)
(defprimitive >= "SCM_GeP" 2)
(defprimitive = "SCM_EqnP" 2)
(defprimitive < "SCM_LtP" 2)
(defprimitive > "SCM_GtP" 2)

(defprimitive call/ep "SCM_callep" 1)
(defprimitive print "SCM_print" 1)

;;; Not really true since SCM_prin is only monadic whereas display may
;;; have an optional port:

(defprimitive display "SCM_prin" 1)

;;; Define as well some global constants

(define-syntax definitial
  (syntax-rules ()
    ((definitial name value)
     (let ((v (make-Predefined-Variable 
               'name (make-Constant-Description value) )))
       (set! g.init (cons v g.init))
       'name ) ) ) )

(definitial t   "SCM_true")
(definitial f   "SCM_false")
(definitial nil "SCM_nil")

;;; Apply is a special case. It has to be invoked specially as an nary
;;; subr.  It is not inlined.

(begin
  (set! g.init (append (map (lambda (name) 
                              (make-Predefined-Variable name #f) )
                            '(list apply call/cc) )
                       g.init ))
  'apply )

;;;ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;;; This is very restrictive and can be extended.

;; The addition of arguments->C-with-casts is a hack to avoid a gcc
;; warning about passing a SCM pointer to system(3). There are several
;; less-hackish ways to fix this, but all require more code and would
;; cause the code in this repo to diverge needlessly from the code
;; presented in the book. We could ignore the warning, but this code
;; is isolated enough that fixing it doesn't cause too much of a mess
;; and it helps soothe the soul.
(define-generic (arguments->C-with-casts (e) casts out))

(define-method (arguments->C-with-casts (e Arguments) casts out)
  (between-parentheses out
    (format out (car casts)))
  (->C (Arguments-first e) out)
  (arguments->C-with-casts (Arguments-others e) (cdr casts) out) )

(define-method (arguments->C-with-casts (e No-Argument) casts out)
  #t )

(define (repeat x n)
  (if (zero? n)
      '()
      (cons x (repeat x (- n 1))) ) )

(define-syntax defforeignprimitive
  (syntax-rules (int string)
    ((defforeignprimitive name int (Cname string) arity)
     (let ((v (make-Predefined-Variable 
               'name (make-Functional-Description 
                      = arity 
                      (lambda (e out)
                        (format out "SCM_Int2fixnum")
                        (between-parentheses out
                          (format out "~A" Cname)
                          (between-parentheses out
			    (let ((args (Predefined-Application-arguments e)))
			      (arguments->C-with-casts
			        args
				(repeat "const char *" (number-of args))
				out )) ) ) ) ) )))
       (set! g.init (cons v g.init))
       'name ) ) ) )

(defforeignprimitive system int ("system" string) 1)

;;;ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;;; This is used to generate parts of the scheme.{c,h} files.

;(define (generate-prototypes g out)
;  (for-each (lambda (gv)
;              (let ((desc (Predefined-Variable-description gv)))
;                (cond ((Functional-Description? desc)
;                       (format out "SCM_DefinePredefinedVariable(")
;                       (variable->C gv out)
;                       (format out ",\"~A\",~A,~A);~%"
;                               (Variable-name gv)
;                               (Functional-Description-arity desc)
;                               (Functional-Description-Cname desc) ) )
;                      ((Constant-Description? desc)
;                       (format out "SCM_DefineInitializedGlobalVariable(")
;                       (variable->C gv out)
;                       (format out ",\"~A\",~A);~%"
;                               (Variable-name gv)
;                               (Constant-Description-value desc) ) ) ) ) )
;            g ) )
;;; (generate-prototypes g.init (current-output-port))

;(define (generate-declarations g out)
;  (for-each (lambda (gv)
;              (let ((desc (Predefined-Variable-description gv)))
;                (cond ((Functional-Description? desc)
;                       (format out "SCM_DeclareSubr~A("
;                               (Functional-Description-arity desc) )
;                       (variable->C gv out)
;                       (format out ",~A);~%" 
;                               (Functional-Description-Cname desc) ) )
;                      ((Constant-Description? desc)
;                       (format out "SCM_DeclareConstant(")
;                       (variable->C gv out)
;                       (format out ");~%") ) ) ) )
;            g ) )
;;; (generate-declarations g.init (current-output-port))

;;; end of chap10h.scm

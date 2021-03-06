;; Copyright 2015-2018
;; Kaz Kylheku <kaz@kylheku.com>
;; Vancouver, Canada
;; All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are met:
;;
;; 1. Redistributions of source code must retain the above copyright notice, this
;;    list of conditions and the following disclaimer.
;;
;; 2. Redistributions in binary form must reproduce the above copyright notice,
;;    this list of conditions and the following disclaimer in the documentation
;;    and/or other materials provided with the distribution.
;;
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
;; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
;; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
;; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
;; CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
;; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(defun sys:handle-bad-syntax (item)
  (throwf 'eval-error "~s: bad clause syntax: ~s" 'handle item))

(defmacro usr:catch (:form form :env e try-form . catch-clauses)
  (let ((catch-syms [mapcar car catch-clauses])
        (sys-catch-clauses (mapcar (do mac-param-bind @1 (type args . body) @1
                                     (tree-bind (args-ex . body-ex)
                                                (sys:expand-params args body
                                                                   e nil form)
                                       ^(,type (,(gensym) ,*args-ex) ,*body-ex)))
                                   catch-clauses)))
    ^(sys:catch ,catch-syms ,try-form ,*sys-catch-clauses)))

(defmacro catch* (try-form . catch-clauses)
  (let ((catch-syms [mapcar car catch-clauses]))
    ^(sys:catch ,catch-syms ,try-form ,*catch-clauses)))

(defun sys:expand-handle (form try-form handle-clauses)
  (let* ((oper (car form))
         (exc-sym (gensym))
         (exc-args (gensym))
         (syms-fragments (collect-each ((hc handle-clauses))
                          (tree-case hc
                            ((name arglist . body)
                             (unless (symbolp name)
                               (sys:handle-bad-syntax hc))
                             (list name ^(apply (lambda ,arglist ,*body)
                                                ,*(if (or (eq oper 'handle*)
                                                          (and (plusp sys:compat)
                                                               (<= 161 sys:compat)))
                                                    ^(,exc-sym))
                                                ,exc-args)))
                            (else (sys:handle-bad-syntax hc))))))
    ^(handler-bind (lambda (,exc-sym . ,exc-args)
                     (cond
                       ,*(mapcar (aret ^((exception-subtype-p ,exc-sym ',@1) ,@2))
                                 syms-fragments)))
                   ,[mapcar car syms-fragments]
                   ,try-form)))

(defmacro handle (:form form try-form . handle-clauses)
  (sys:expand-handle form try-form handle-clauses))

(defmacro handle* (:form form try-form . handle-clauses)
  (sys:expand-handle form try-form handle-clauses))

(defmacro ignwarn (. forms)
  ^(handler-bind (lambda (exc-sym arg) (throw 'continue)) (warning) ,*forms))

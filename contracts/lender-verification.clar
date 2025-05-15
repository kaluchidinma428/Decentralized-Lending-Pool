;; Lender Verification Contract
;; Validates funding participants in the lending pool

(define-data-var minimum-deposit uint u1000000) ;; Minimum tokens to become a lender

;; Map of verified lenders
(define-map lenders principal bool)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-ALREADY-VERIFIED u2)
(define-constant ERR-INSUFFICIENT-DEPOSIT u3)

;; Check if a principal is a verified lender
(define-read-only (is-verified-lender (lender principal))
  (default-to false (map-get? lenders lender))
)

;; Set minimum deposit requirement (only owner can change)
(define-public (set-minimum-deposit (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set minimum-deposit amount))
  )
)

;; Register as a lender
(define-public (register-lender (deposit uint))
  (begin
    ;; Check if already verified
    (asserts! (not (is-verified-lender tx-sender)) (err ERR-ALREADY-VERIFIED))
    ;; Check if deposit is sufficient
    (asserts! (>= deposit (var-get minimum-deposit)) (err ERR-INSUFFICIENT-DEPOSIT))
    ;; Add to verified lenders map
    (map-set lenders tx-sender true)
    (ok true)
  )
)

;; Remove lender (can be called by owner or lender themself)
(define-public (remove-lender (lender principal))
  (begin
    (asserts! (or (is-eq tx-sender lender) (is-eq tx-sender (var-get contract-owner))) (err ERR-NOT-AUTHORIZED))
    (map-delete lenders lender)
    (ok true)
  )
)

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set contract-owner new-owner))
  )
)

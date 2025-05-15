;; Borrower Verification Contract
;; Validates loan recipients

;; Map of verified borrowers
(define-map borrowers principal {
  credit-score: uint,
  verified: bool,
  max-borrow-amount: uint
})

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-ALREADY-VERIFIED u2)
(define-constant ERR-INVALID-CREDIT-SCORE u3)

;; Check if a principal is a verified borrower
(define-read-only (is-verified-borrower (borrower principal))
  (match (map-get? borrowers borrower)
    borrower-data (get verified borrower-data)
    false
  )
)

;; Get borrower data
(define-read-only (get-borrower-data (borrower principal))
  (map-get? borrowers borrower)
)

;; Get maximum borrow amount for a borrower
(define-read-only (get-max-borrow-amount (borrower principal))
  (default-to u0
    (match (map-get? borrowers borrower)
      borrower-data (some (get max-borrow-amount borrower-data))
      none
    )
  )
)

;; Register borrower (only contract owner can do this)
(define-public (register-borrower (borrower principal) (credit-score uint) (max-amount uint))
  (begin
    ;; Check authorization
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    ;; Check if already verified
    (asserts! (not (is-verified-borrower borrower)) (err ERR-ALREADY-VERIFIED))
    ;; Check credit score validity (example: score must be between 300-850)
    (asserts! (and (>= credit-score u300) (<= credit-score u850)) (err ERR-INVALID-CREDIT-SCORE))

    ;; Add to verified borrowers map
    (map-set borrowers borrower {
      credit-score: credit-score,
      verified: true,
      max-borrow-amount: max-amount
    })
    (ok true)
  )
)

;; Update borrower data
(define-public (update-borrower (borrower principal) (credit-score uint) (max-amount uint))
  (begin
    ;; Check authorization
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))

    ;; Check credit score validity
    (asserts! (and (>= credit-score u300) (<= credit-score u850)) (err ERR-INVALID-CREDIT-SCORE))

    ;; Update in verified borrowers map
    (map-set borrowers borrower {
      credit-score: credit-score,
      verified: true,
      max-borrow-amount: max-amount
    })
    (ok true)
  )
)

;; Remove borrower
(define-public (remove-borrower (borrower principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (map-delete borrowers borrower)
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

;; Repayment Tracking Contract
;; Manages loan servicing and collections

;; Loan structure
(define-map loans uint {
  borrower: principal,
  lender: principal,
  amount: uint,
  interest-rate: uint,
  term-length: uint,
  start-block: uint,
  collateral-id: uint,
  total-repaid: uint,
  status: (string-ascii 20)
})

;; Repayment history
(define-map repayments (tuple (loan-id uint) (payment-id uint)) {
  amount: uint,
  block-height: uint
})

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Authorized contract list
(define-map authorized-contracts principal bool)

;; Payment counter per loan
(define-map payment-counters uint uint)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-LOAN-NOT-FOUND u2)
(define-constant ERR-INVALID-STATUS u3)
(define-constant ERR-PAYMENT-TOO-SMALL u4)

;; Helper to check if caller is authorized
(define-private (is-authorized)
  (or
    (is-eq tx-sender (var-get contract-owner))
    (default-to false (map-get? authorized-contracts tx-sender))
  )
)

;; Add an authorized contract
(define-public (add-authorized-contract (contract-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (map-set authorized-contracts contract-principal true))
  )
)

;; Create a new loan
(define-public (create-loan
  (loan-id uint)
  (borrower principal)
  (lender principal)
  (amount uint)
  (interest-rate uint)
  (term-length uint)
  (collateral-id uint)
)
  (begin
    (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
    (map-set loans loan-id {
      borrower: borrower,
      lender: lender,
      amount: amount,
      interest-rate: interest-rate,
      term-length: term-length,
      start-block: block-height,
      collateral-id: collateral-id,
      total-repaid: u0,
      status: "active"
    })
    (map-set payment-counters loan-id u0)
    (ok true)
  )
)

;; Get loan details
(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

;; Record a loan repayment
(define-public (record-repayment (loan-id uint) (amount uint))
  (let
    (
      (loan (map-get? loans loan-id))
      (payment-id (default-to u0 (map-get? payment-counters loan-id)))
      (next-payment-id (+ payment-id u1))
    )
    (begin
      (asserts! (is-some loan) (err ERR-LOAN-NOT-FOUND))
      (asserts! (is-eq (get status (unwrap-panic loan)) "active") (err ERR-INVALID-STATUS))
      (asserts! (> amount u0) (err ERR-PAYMENT-TOO-SMALL))

      ;; Record the payment
      (map-set repayments (tuple (loan-id loan-id) (payment-id payment-id)) {
        amount: amount,
        block-height: block-height
      })

      ;; Update payment counter
      (map-set payment-counters loan-id next-payment-id)

      ;; Update loan total repaid
      (map-set loans loan-id
        (merge (unwrap-panic loan)
          { total-repaid: (+ (get total-repaid (unwrap-panic loan)) amount) }
        )
      )

      ;; Check if loan is fully repaid
      (if (>= (+ (get total-repaid (unwrap-panic loan)) amount) (get amount (unwrap-panic loan)))
        (begin
          (map-set loans loan-id
            (merge (unwrap-panic loan) { status: "repaid" })
          )
          (ok true)
        )
        (ok true)
      )
    )
  )
)

;; Calculate amount due for a loan
(define-read-only (calculate-amount-due (loan-id uint))
  (let ((loan (map-get? loans loan-id)))
    (match loan
      loan-data
        (let
          (
            (principal-amount (get amount loan-data))
            (interest-rate (get interest-rate loan-data))
            (term (get term-length loan-data))
            (repaid (get total-repaid loan-data))
            (interest-amount (/ (* principal-amount interest-rate term) u10000))
            (total-due (+ principal-amount interest-amount))
          )
          (if (>= repaid total-due)
            u0
            (- total-due repaid)
          )
        )
      u0
    )
  )
)

;; Mark loan as defaulted
(define-public (mark-loan-defaulted (loan-id uint))
  (let ((loan (map-get? loans loan-id)))
    (begin
      (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
      (asserts! (is-some loan) (err ERR-LOAN-NOT-FOUND))
      (asserts! (is-eq (get status (unwrap-panic loan)) "active") (err ERR-INVALID-STATUS))

      (map-set loans loan-id
        (merge (unwrap-panic loan) { status: "defaulted" })
      )
      (ok true)
    )
  )
)

;; Get repayment history for a loan
(define-read-only (get-repayment (loan-id uint) (payment-id uint))
  (map-get? repayments (tuple (loan-id loan-id) (payment-id payment-id)))
)

;; Get total repayments count for a loan
(define-read-only (get-repayment-count (loan-id uint))
  (default-to u0 (map-get? payment-counters loan-id))
)

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set contract-owner new-owner))
  )
)

;; Collateral Management Contract
;; Tracks assets securing loans

;; Map of collateral by loan ID
(define-map collaterals uint {
  borrower: principal,
  asset-type: (string-ascii 20),
  asset-value: uint,
  locked: bool
})

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Authorized contract list
(define-map authorized-contracts principal bool)

;; Counter for loan IDs
(define-data-var loan-id-counter uint u0)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-COLLATERAL-NOT-FOUND u2)
(define-constant ERR-COLLATERAL-LOCKED u3)
(define-constant ERR-INSUFFICIENT-COLLATERAL u4)

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

;; Remove an authorized contract
(define-public (remove-authorized-contract (contract-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (map-delete authorized-contracts contract-principal))
  )
)

;; Generate a new loan ID
(define-private (generate-loan-id)
  (let ((current-id (var-get loan-id-counter)))
    (var-set loan-id-counter (+ current-id u1))
    current-id
  )
)

;; Add collateral for a loan
(define-public (add-collateral (borrower principal) (asset-type (string-ascii 20)) (asset-value uint))
  (let ((loan-id (generate-loan-id)))
    (begin
      (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
      (asserts! (> asset-value u0) (err ERR-INSUFFICIENT-COLLATERAL))

      (map-set collaterals loan-id {
        borrower: borrower,
        asset-type: asset-type,
        asset-value: asset-value,
        locked: true
      })
      (ok loan-id)
    )
  )
)

;; Get collateral details
(define-read-only (get-collateral (loan-id uint))
  (map-get? collaterals loan-id)
)

;; Update collateral value
(define-public (update-collateral-value (loan-id uint) (new-value uint))
  (let ((collateral (map-get? collaterals loan-id)))
    (begin
      (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
      (asserts! (is-some collateral) (err ERR-COLLATERAL-NOT-FOUND))

      (map-set collaterals loan-id (merge (unwrap-panic collateral) {asset-value: new-value}))
      (ok true)
    )
  )
)

;; Release collateral
(define-public (release-collateral (loan-id uint))
  (let ((collateral (map-get? collaterals loan-id)))
    (begin
      (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
      (asserts! (is-some collateral) (err ERR-COLLATERAL-NOT-FOUND))

      (map-set collaterals loan-id (merge (unwrap-panic collateral) {locked: false}))
      (ok true)
    )
  )
)

;; Liquidate collateral
(define-public (liquidate-collateral (loan-id uint))
  (let ((collateral (map-get? collaterals loan-id)))
    (begin
      (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
      (asserts! (is-some collateral) (err ERR-COLLATERAL-NOT-FOUND))
      (asserts! (get locked (unwrap-panic collateral)) (err ERR-COLLATERAL-LOCKED))

      ;; In a real implementation, this would handle the actual liquidation
      ;; Here we're just marking it as released
      (map-set collaterals loan-id (merge (unwrap-panic collateral) {locked: false}))
      (ok true)
    )
  )
)

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set contract-owner new-owner))
  )
)

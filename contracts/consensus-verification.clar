;; Consensus Verification Contract
;; Validates cross-chain transactions through consensus mechanisms

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_TRANSACTION (err u401))
(define-constant ERR_INSUFFICIENT_CONFIRMATIONS (err u402))
(define-constant ERR_TRANSACTION_NOT_FOUND (err u403))

;; Transaction verification data
(define-map transactions
  { tx-hash: (string-ascii 64) }
  {
    source-chain: uint,
    target-chain: uint,
    amount: uint,
    sender: (string-ascii 100),
    recipient: (string-ascii 100),
    confirmations: uint,
    required-confirmations: uint,
    status: (string-ascii 20),
    timestamp: uint
  }
)

;; Validator confirmations
(define-map validator-confirmations
  { tx-hash: (string-ascii 64), validator: principal }
  { confirmed: bool, timestamp: uint }
)

;; Minimum required confirmations
(define-data-var min-confirmations uint u3)

;; Submit transaction for verification
(define-public (submit-transaction
  (tx-hash (string-ascii 64))
  (source-chain uint)
  (target-chain uint)
  (amount uint)
  (sender (string-ascii 100))
  (recipient (string-ascii 100))
  (required-confirmations uint)
)
  (begin
    (map-set transactions
      { tx-hash: tx-hash }
      {
        source-chain: source-chain,
        target-chain: target-chain,
        amount: amount,
        sender: sender,
        recipient: recipient,
        confirmations: u0,
        required-confirmations: required-confirmations,
        status: "pending",
        timestamp: block-height
      }
    )
    (ok true)
  )
)

;; Validator confirms transaction
(define-public (confirm-transaction (tx-hash (string-ascii 64)))
  (match (map-get? transactions { tx-hash: tx-hash })
    tx-data (begin
      ;; Record validator confirmation
      (map-set validator-confirmations
        { tx-hash: tx-hash, validator: tx-sender }
        { confirmed: true, timestamp: block-height }
      )

      ;; Update confirmation count
      (let ((new-confirmations (+ (get confirmations tx-data) u1)))
        (map-set transactions
          { tx-hash: tx-hash }
          (merge tx-data { confirmations: new-confirmations })
        )

        ;; Check if enough confirmations
        (if (>= new-confirmations (get required-confirmations tx-data))
          (begin
            (map-set transactions
              { tx-hash: tx-hash }
              (merge tx-data {
                confirmations: new-confirmations,
                status: "confirmed"
              })
            )
            (ok "confirmed")
          )
          (ok "pending")
        )
      )
    )
    ERR_TRANSACTION_NOT_FOUND
  )
)

;; Get transaction status
(define-read-only (get-transaction (tx-hash (string-ascii 64)))
  (map-get? transactions { tx-hash: tx-hash })
)

;; Check if transaction is confirmed
(define-read-only (is-confirmed (tx-hash (string-ascii 64)))
  (match (map-get? transactions { tx-hash: tx-hash })
    tx-data (ok (>= (get confirmations tx-data) (get required-confirmations tx-data)))
    ERR_TRANSACTION_NOT_FOUND
  )
)

;; Get validator confirmation
(define-read-only (get-validator-confirmation (tx-hash (string-ascii 64)) (validator principal))
  (map-get? validator-confirmations { tx-hash: tx-hash, validator: validator })
)

;; Update minimum confirmations
(define-public (set-min-confirmations (new-min uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set min-confirmations new-min)
    (ok true)
  )
)

;; Bridge Protocol Contract
;; Manages inter-blockchain communication for supply chain data

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_BRIDGE (err u301))
(define-constant ERR_BRIDGE_NOT_FOUND (err u302))
(define-constant ERR_TRANSFER_FAILED (err u303))

;; Bridge connection data
(define-map bridges
  { bridge-id: uint }
  {
    source-chain: uint,
    target-chain: uint,
    is-active: bool,
    fee-rate: uint,
    created-at: uint
  }
)

;; Cross-chain messages
(define-map cross-chain-messages
  { message-id: (string-ascii 64) }
  {
    bridge-id: uint,
    sender: principal,
    recipient: (string-ascii 100),
    payload: (string-ascii 1000),
    status: (string-ascii 20),
    timestamp: uint
  }
)

;; Bridge counter
(define-data-var bridge-counter uint u0)

;; Create a new bridge connection
(define-public (create-bridge (source-chain uint) (target-chain uint) (fee-rate uint))
  (let ((bridge-id (+ (var-get bridge-counter) u1)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set bridges
      { bridge-id: bridge-id }
      {
        source-chain: source-chain,
        target-chain: target-chain,
        is-active: true,
        fee-rate: fee-rate,
        created-at: block-height
      }
    )

    (var-set bridge-counter bridge-id)
    (ok bridge-id)
  )
)

;; Send cross-chain message
(define-public (send-message
  (message-id (string-ascii 64))
  (bridge-id uint)
  (recipient (string-ascii 100))
  (payload (string-ascii 1000))
)
  (begin
    (asserts! (is-some (map-get? bridges { bridge-id: bridge-id })) ERR_BRIDGE_NOT_FOUND)

    (map-set cross-chain-messages
      { message-id: message-id }
      {
        bridge-id: bridge-id,
        sender: tx-sender,
        recipient: recipient,
        payload: payload,
        status: "pending",
        timestamp: block-height
      }
    )
    (ok true)
  )
)

;; Update message status
(define-public (update-message-status (message-id (string-ascii 64)) (status (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? cross-chain-messages { message-id: message-id })
      message-data (begin
        (map-set cross-chain-messages
          { message-id: message-id }
          (merge message-data { status: status })
        )
        (ok true)
      )
      ERR_TRANSFER_FAILED
    )
  )
)

;; Get bridge information
(define-read-only (get-bridge (bridge-id uint))
  (map-get? bridges { bridge-id: bridge-id })
)

;; Get message information
(define-read-only (get-message (message-id (string-ascii 64)))
  (map-get? cross-chain-messages { message-id: message-id })
)

;; Activate/deactivate bridge
(define-public (toggle-bridge (bridge-id uint) (active bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? bridges { bridge-id: bridge-id })
      bridge-data (begin
        (map-set bridges
          { bridge-id: bridge-id }
          (merge bridge-data { is-active: active })
        )
        (ok true)
      )
      ERR_BRIDGE_NOT_FOUND
    )
  )
)

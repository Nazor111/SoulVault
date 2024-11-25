;; SoulStamp - Non-transferable Soulbound Token System

(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-already-exists (err u101))
(define-constant err-invalid-user (err u102))
(define-constant err-token-not-found (err u103))

;; Data Maps
(define-map user-tokens 
    { user: principal } 
    { tokens: (list 50 uint) }
)

(define-map token-details
    { token-id: uint }
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        category: (string-ascii 20),
        timestamp: uint,
        issuer: principal
    }
)

(define-map categories 
    { category: (string-ascii 20) }
    { active: bool }
)

;; Initialize categories
(define-data-var next-token-id uint u1)

;; Public Functions

(define-public (issue-token 
    (recipient principal)
    (name (string-ascii 50))
    (description (string-ascii 200))
    (category (string-ascii 20)))
    (let
        ((token-id (var-get next-token-id)))
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (is-valid-category category) err-invalid-user)
        
        ;; Create token details
        (map-set token-details
            { token-id: token-id }
            {
                name: name,
                description: description,
                category: category,
                timestamp: block-height,
                issuer: tx-sender
            }
        )
        
        ;; Add token to user's collection
        (match (map-get? user-tokens { user: recipient })
            existing-data
            (map-set user-tokens
                { user: recipient }
                { tokens: (unwrap-panic (as-max-len? 
                    (append (get tokens existing-data) token-id) u50)) }
            )
            (map-set user-tokens
                { user: recipient }
                { tokens: (list token-id) }
            )
        )
        
        ;; Increment token ID
        (var-set next-token-id (+ token-id u1))
        (ok token-id)
    )
)

(define-public (add-category (category (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (map-set categories 
            { category: category }
            { active: true }
        )
        (ok true)
    )
)

;; Read-Only Functions

(define-read-only (get-token-details (token-id uint))
    (map-get? token-details { token-id: token-id })
)

(define-read-only (get-user-tokens (user principal))
    (map-get? user-tokens { user: user })
)

(define-read-only (is-valid-category (category (string-ascii 20)))
    (default-to
        false
        (get active (map-get? categories { category: category }))
    )
)

;; Private Functions

(define-private (is-owner (token-id uint) (user principal))
    (match (map-get? user-tokens { user: user })
        existing-data
        (is-some (index-of (get tokens existing-data) token-id))
        false
    )
)
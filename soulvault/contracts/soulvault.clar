;; SoulStamp - Non-transferable Soulbound Token System with Emergency Features

;; Constants
(define-constant contract-owner tx-sender)

;; Error Codes
(define-constant err-not-authorized (err u100))
(define-constant err-already-exists (err u101))
(define-constant err-invalid-user (err u102))
(define-constant err-token-not-found (err u103))
(define-constant err-insufficient-approvals (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-no-emergency (err u106))
(define-constant err-expired (err u107))
(define-constant err-category-inactive (err u108))
(define-constant err-invalid-guardian (err u109))
(define-constant err-invalid-input (err u110))
(define-constant err-empty-string (err u111))

;; Data Variables
(define-data-var next-token-id uint u1)
(define-data-var required-approvals uint u3)
(define-data-var proposal-duration uint u144)  ;; ~24 hours in blocks
(define-data-var guardian-count uint u0)
(define-data-var emergency-cooldown uint u720) ;; ~5 days in blocks

;; Data Maps
(define-map user-tokens 
    { user: principal } 
    { 
        tokens: (list 50 uint),
        last-emergency: uint  ;; Last emergency proposal timestamp
    }
)

(define-map token-details
    { token-id: uint }
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        category: (string-ascii 20),
        timestamp: uint,
        issuer: principal,
        emergency-status: bool,
        revoked: bool
    }
)

(define-map categories 
    { category: (string-ascii 20) }
    { 
        active: bool,
        created-at: uint,
        created-by: principal
    }
)

(define-map emergency-guardians
    { guardian: principal }
    { 
        active: bool,
        reputation: uint,
        added-at: uint,
        votes-cast: uint
    }
)

(define-map emergency-proposals
    { token-id: uint }
    {
        proposer: principal,
        reason: (string-ascii 200),
        timestamp: uint,
        approval-count: uint,
        status: (string-ascii 20),
        expiry: uint,
        executed-at: (optional uint)
    }
)

(define-map guardian-votes
    { token-id: uint, guardian: principal }
    { 
        voted: bool,
        vote: bool,
        timestamp: uint
    }
)

;; Input Validation Functions

(define-private (is-valid-category (category (string-ascii 20)))
    (and 
        (not (is-eq category ""))
        (match (map-get? categories { category: category })
            category-data (get active category-data)
            false
        )
    )
)

(define-private (is-valid-guardian (guardian principal))
    (and
        (not (is-eq guardian contract-owner))
        (match (map-get? emergency-guardians { guardian: guardian })
            guardian-data (get active guardian-data)
            false
        )
    )
)

(define-private (is-valid-token-id (token-id uint))
    (< u0 token-id)
)

(define-private (is-valid-string (str (string-ascii 200)))
    (not (is-eq str ""))
)

;; Administrative Functions

(define-public (add-category (category (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (not (is-eq category "")) err-empty-string)
        (asserts! (is-none (map-get? categories { category: category })) err-already-exists)
        (map-set categories 
            { category: category }
            { 
                active: true,
                created-at: block-height,
                created-by: tx-sender
            }
        )
        (ok true)
    )
)

(define-public (deactivate-category (category (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (not (is-eq category "")) err-empty-string)
        (asserts! (is-valid-category category) err-invalid-input)
        (map-set categories 
            { category: category }
            (merge 
                (unwrap! (map-get? categories { category: category }) err-invalid-user)
                { active: false }
            )
        )
        (ok true)
    )
)

(define-public (add-guardian (new-guardian principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (not (is-eq new-guardian contract-owner)) err-invalid-input)
        (asserts! (is-none (map-get? emergency-guardians { guardian: new-guardian })) err-already-exists)
        (map-set emergency-guardians
            { guardian: new-guardian }
            { 
                active: true,
                reputation: u100,
                added-at: block-height,
                votes-cast: u0
            }
        )
        (var-set guardian-count (+ (var-get guardian-count) u1))
        (ok true)
    )
)

(define-public (remove-guardian (guardian principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (is-valid-guardian guardian) err-invalid-guardian)
        (map-set emergency-guardians
            { guardian: guardian }
            (merge 
                (unwrap! (map-get? emergency-guardians { guardian: guardian }) err-invalid-guardian)
                { active: false }
            )
        )
        (var-set guardian-count (- (var-get guardian-count) u1))
        (ok true)
    )
)

;; Token Management Functions

(define-public (issue-token 
    (recipient principal)
    (name (string-ascii 50))
    (description (string-ascii 200))
    (category (string-ascii 20)))
    (let
        ((token-id (var-get next-token-id)))
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (not (is-eq recipient contract-owner)) err-invalid-input)
        (asserts! (not (is-eq name "")) err-empty-string)
        (asserts! (not (is-eq description "")) err-empty-string)
        (asserts! (is-valid-category category) err-category-inactive)
        
        ;; Create token details
        (map-set token-details
            { token-id: token-id }
            {
                name: name,
                description: description,
                category: category,
                timestamp: block-height,
                issuer: tx-sender,
                emergency-status: false,
                revoked: false
            }
        )
        
        ;; Add token to user's collection
        (match (map-get? user-tokens { user: recipient })
            existing-data
            (map-set user-tokens
                { user: recipient }
                { 
                    tokens: (unwrap-panic (as-max-len? 
                        (append (get tokens existing-data) token-id) u50)),
                    last-emergency: (get last-emergency existing-data)
                }
            )
            (map-set user-tokens
                { user: recipient }
                { 
                    tokens: (list token-id),
                    last-emergency: u0
                }
            )
        )
        
        (var-set next-token-id (+ token-id u1))
        (ok token-id)
    )
)

;; Emergency System Functions

(define-public (propose-emergency-unlock 
    (token-id uint)
    (reason (string-ascii 200)))
    (let
        ((user-data (unwrap! (map-get? user-tokens { user: tx-sender }) err-not-authorized))
         (current-time block-height))
        
        ;; Verify ownership, cooldown, and valid token-id
        (asserts! (is-valid-token-id token-id) err-invalid-input)
        (asserts! (is-valid-string reason) err-empty-string)
        (asserts! (is-owner token-id tx-sender) err-not-authorized)
        (asserts! (> current-time (+ (get last-emergency user-data) 
                                    (var-get emergency-cooldown))) 
                 err-already-exists)
        
        ;; Create proposal
        (map-set emergency-proposals
            { token-id: token-id }
            {
                proposer: tx-sender,
                reason: reason,
                timestamp: current-time,
                approval-count: u0,
                status: "pending",
                expiry: (+ current-time (var-get proposal-duration)),
                executed-at: none
            }
        )
        
        ;; Update user's last emergency timestamp
        (map-set user-tokens 
            { user: tx-sender }
            (merge user-data { last-emergency: current-time })
        )
        
        (ok true)
    )
)

(define-public (vote-on-emergency 
    (token-id uint)
    (approve bool))
    (let
        ((proposal (unwrap! (map-get? emergency-proposals { token-id: token-id }) 
                           err-token-not-found))
         (guardian-data (unwrap! (map-get? emergency-guardians { guardian: tx-sender })
                                err-not-authorized)))
        
        ;; Verify voting eligibility and valid token-id
        (asserts! (is-valid-token-id token-id) err-invalid-input)
        (asserts! (get active guardian-data) err-not-authorized)
        (asserts! (is-none (map-get? guardian-votes 
            { token-id: token-id, guardian: tx-sender })) err-already-voted)
        (asserts! (< block-height (get expiry proposal)) err-expired)
        (asserts! (is-eq (get status proposal) "pending") err-already-exists)
        
        ;; Record vote
        (map-set guardian-votes
            { token-id: token-id, guardian: tx-sender }
            { 
                voted: true,
                vote: approve,
                timestamp: block-height
            }
        )
        
        ;; Update guardian stats
        (map-set emergency-guardians
            { guardian: tx-sender }
            (merge guardian-data 
                { votes-cast: (+ (get votes-cast guardian-data) u1) })
        )
        
        ;; Update approval count if approved
        (if approve
            (merge-emergency-proposal token-id 
                (+ (get approval-count proposal) u1))
            (ok true)
        )
    )
)

(define-public (execute-emergency-unlock (token-id uint))
    (let
        ((proposal (unwrap! (map-get? emergency-proposals { token-id: token-id })
                           err-token-not-found)))
        
        ;; Verify execution conditions and valid token-id
        (asserts! (is-valid-token-id token-id) err-invalid-input)
        (asserts! (is-eq (get status proposal) "pending") err-no-emergency)
        (asserts! (>= (get approval-count proposal) (var-get required-approvals))
                 err-insufficient-approvals)
        (asserts! (< block-height (get expiry proposal)) err-expired)
        
        ;; Update token status
        (map-set token-details
            { token-id: token-id }
            (merge
                (unwrap! (get-token-details token-id) err-token-not-found)
                { emergency-status: true }
            )
        )
        
        ;; Update proposal status
        (map-set emergency-proposals
            { token-id: token-id }
            (merge proposal { 
                status: "executed",
                executed-at: (some block-height)
            })
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

(define-read-only (get-emergency-proposal (token-id uint))
    (map-get? emergency-proposals { token-id: token-id })
)

(define-read-only (get-guardian-status (guardian principal))
    (map-get? emergency-guardians { guardian: guardian })
)

;; Private Helper Functions

(define-private (is-owner (token-id uint) (user principal))
    (match (map-get? user-tokens { user: user })
        existing-data
        (is-some (index-of (get tokens existing-data) token-id))
        false
    )
)

(define-private (merge-emergency-proposal (token-id uint) (new-count uint))
    (let
        ((proposal (unwrap! (map-get? emergency-proposals { token-id: token-id })
                           err-token-not-found)))
        (map-set emergency-proposals
            { token-id: token-id }
            (merge proposal { approval-count: new-count })
        )
        (ok true)
    )
)
;; Open Source Learning Rewards Smart Contract
;; Compensate creators of educational content through usage metrics

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101)) 
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-content-not-active (err u106))

;; Data Variables
(define-data-var next-content-id uint u1)
(define-data-var reward-pool uint u0)
(define-data-var platform-fee-percentage uint u5) ;; 5% platform fee

;; Data Maps
(define-map content-registry
    { content-id: uint }
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        content-hash: (string-ascii 64),
        category: (string-ascii 50),
        created-at: uint,
        total-views: uint,
        total-completions: uint,
        total-ratings: uint,
        rating-sum: uint,
        reward-earned: uint,
        is-active: bool
    }
)

(define-map creator-profiles
    { creator: principal }
    {
        username: (string-ascii 50),
        bio: (string-ascii 200),
        total-content: uint,
        total-earnings: uint,
        reputation-score: uint,
        joined-at: uint
    }
)

(define-map user-interactions
    { user: principal, content-id: uint }
    {
        viewed: bool,
        completed: bool,
        rating: uint,
        interaction-time: uint
    }
)

(define-map content-rewards
    { content-id: uint }
    {
        base-reward: uint,
        view-multiplier: uint,
        completion-multiplier: uint,
        rating-multiplier: uint,
        last-calculated: uint
    }
)

(define-map user-balances
    { user: principal }
    { balance: uint }
)

;; Public Functions

;; Initialize creator profile
(define-public (create-creator-profile (username (string-ascii 50)) (bio (string-ascii 200)))
    (let ((creator tx-sender))
        (asserts! (is-none (map-get? creator-profiles { creator: creator })) err-already-exists)
        (map-set creator-profiles
            { creator: creator }
            {
                username: username,
                bio: bio,
                total-content: u0,
                total-earnings: u0,
                reputation-score: u100,
                joined-at: block-height
            }
        )
        (ok true)
    )
)

;; Register new educational content
(define-public (register-content 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (content-hash (string-ascii 64))
    (category (string-ascii 50))
    (base-reward uint))
    (let (
        (content-id (var-get next-content-id))
        (creator tx-sender)
    )
        (asserts! (> base-reward u0) err-invalid-amount)
        
        ;; Register content
        (map-set content-registry
            { content-id: content-id }
            {
                creator: creator,
                title: title,
                description: description,
                content-hash: content-hash,
                category: category,
                created-at: block-height,
                total-views: u0,
                total-completions: u0,
                total-ratings: u0,
                rating-sum: u0,
                reward-earned: u0,
                is-active: true
            }
        )
        
        ;; Set reward parameters
        (map-set content-rewards
            { content-id: content-id }
            {
                base-reward: base-reward,
                view-multiplier: u10,
                completion-multiplier: u100,
                rating-multiplier: u50,
                last-calculated: block-height
            }
        )
        
        ;; Update creator profile
        (update-creator-content-count creator)
        
        ;; Increment content ID
        (var-set next-content-id (+ content-id u1))
        
        (ok content-id)
    )
)

;; Record user interaction with content
(define-public (interact-with-content (content-id uint) (interaction-type (string-ascii 20)))
    (let (
        (user tx-sender)
        (content (unwrap! (map-get? content-registry { content-id: content-id }) err-not-found))
        (existing-interaction (map-get? user-interactions { user: user, content-id: content-id }))
    )
        (asserts! (get is-active content) err-content-not-active)
        
        (if (is-some existing-interaction)
            (update-existing-interaction user content-id interaction-type (unwrap-panic existing-interaction))
            (create-new-interaction user content-id interaction-type)
        )
    )
)

;; Rate content (1-5 stars)
(define-public (rate-content (content-id uint) (rating uint))
    (let (
        (user tx-sender)
        (content (unwrap! (map-get? content-registry { content-id: content-id }) err-not-found))
        (interaction (map-get? user-interactions { user: user, content-id: content-id }))
    )
        (asserts! (get is-active content) err-content-not-active)
        (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-amount)
        (asserts! (is-some interaction) err-unauthorized)
        
        (let ((current-interaction (unwrap-panic interaction)))
            (if (is-eq (get rating current-interaction) u0)
                (begin
                    ;; New rating
                    (map-set user-interactions
                        { user: user, content-id: content-id }
                        (merge current-interaction { rating: rating, interaction-time: block-height })
                    )
                    (update-content-rating content-id rating true)
                )
                (begin
                    ;; Update existing rating
                    (let ((old-rating (get rating current-interaction)))
                        (map-set user-interactions
                            { user: user, content-id: content-id }
                            (merge current-interaction { rating: rating, interaction-time: block-height })
                        )
                        (update-content-rating-change content-id old-rating rating)
                    )
                )
            )
        )
        
        (ok true)
    )
)

;; Calculate and distribute rewards for content
(define-public (calculate-rewards (content-id uint))
    (let (
        (content (unwrap! (map-get? content-registry { content-id: content-id }) err-not-found))
        (reward-params (unwrap! (map-get? content-rewards { content-id: content-id }) err-not-found))
        (creator (get creator content))
    )
        (asserts! (get is-active content) err-content-not-active)
        
        (let (
            (base-reward (get base-reward reward-params))
            (view-score (* (get total-views content) (get view-multiplier reward-params)))
            (completion-score (* (get total-completions content) (get completion-multiplier reward-params)))
            (rating-score (if (> (get total-ratings content) u0)
                            (* (/ (get rating-sum content) (get total-ratings content)) (get rating-multiplier reward-params))
                            u0))
            (total-reward (+ base-reward (+ view-score (+ completion-score rating-score))))
            (platform-fee (/ (* total-reward (var-get platform-fee-percentage)) u100))
            (creator-reward (- total-reward platform-fee))
        )
            ;; Update content reward earned
            (map-set content-registry
                { content-id: content-id }
                (merge content { reward-earned: (+ (get reward-earned content) creator-reward) })
            )
            
            ;; Update reward calculation timestamp
            (map-set content-rewards
                { content-id: content-id }
                (merge reward-params { last-calculated: block-height })
            )
            
            ;; Add to creator balance
            (add-to-user-balance creator creator-reward)
            
            ;; Update creator earnings
            (update-creator-earnings creator creator-reward)
            
            ;; Add platform fee to reward pool
            (var-set reward-pool (+ (var-get reward-pool) platform-fee))
            
            (ok creator-reward)
        )
    )
)

;; Fund reward pool (admin function)
(define-public (fund-reward-pool (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> amount u0) err-invalid-amount)
        (var-set reward-pool (+ (var-get reward-pool) amount))
        (ok true)
    )
)

;; Withdraw earnings
(define-public (withdraw-earnings (amount uint))
    (let (
        (user tx-sender)
        (current-balance (default-to u0 (get balance (map-get? user-balances { user: user }))))
    )
        (asserts! (>= current-balance amount) err-insufficient-balance)
        (asserts! (> amount u0) err-invalid-amount)
        
        (map-set user-balances
            { user: user }
            { balance: (- current-balance amount) }
        )
        
        (ok amount)
    )
)

;; Read-only Functions

;; Get content details
(define-read-only (get-content (content-id uint))
    (map-get? content-registry { content-id: content-id })
)

;; Get creator profile
(define-read-only (get-creator-profile (creator principal))
    (map-get? creator-profiles { creator: creator })
)

;; Get user interaction
(define-read-only (get-user-interaction (user principal) (content-id uint))
    (map-get? user-interactions { user: user, content-id: content-id })
)

;; Get user balance
(define-read-only (get-user-balance (user principal))
    (default-to u0 (get balance (map-get? user-balances { user: user })))
)

;; Get reward pool balance
(define-read-only (get-reward-pool)
    (var-get reward-pool)
)

;; Get content reward parameters
(define-read-only (get-content-rewards (content-id uint))
    (map-get? content-rewards { content-id: content-id })
)

;; Private Functions

;; Update creator content count
(define-private (update-creator-content-count (creator principal))
    (let ((profile (map-get? creator-profiles { creator: creator })))
        (if (is-some profile)
            (let ((current-profile (unwrap-panic profile)))
                (map-set creator-profiles
                    { creator: creator }
                    (merge current-profile { total-content: (+ (get total-content current-profile) u1) })
                )
                true
            )
            false
        )
    )
)

;; Update creator earnings
(define-private (update-creator-earnings (creator principal) (amount uint))
    (let ((profile (map-get? creator-profiles { creator: creator })))
        (if (is-some profile)
            (let ((current-profile (unwrap-panic profile)))
                (map-set creator-profiles
                    { creator: creator }
                    (merge current-profile { 
                        total-earnings: (+ (get total-earnings current-profile) amount),
                        reputation-score: (min u1000 (+ (get reputation-score current-profile) u1))
                    })
                )
                true
            )
            false
        )
    )
)

;; Add to user balance
(define-private (add-to-user-balance (user principal) (amount uint))
    (let ((current-balance (default-to u0 (get balance (map-get? user-balances { user: user })))))
        (map-set user-balances
            { user: user }
            { balance: (+ current-balance amount) }
        )
        true
    )
)

;; Update existing interaction
(define-private (update-existing-interaction (user principal) (content-id uint) (interaction-type (string-ascii 20)) (current-interaction (tuple (viewed bool) (completed bool) (rating uint) (interaction-time uint))))
    (let (
        (new-viewed (if (is-eq interaction-type "view") true (get viewed current-interaction)))
        (new-completed (if (is-eq interaction-type "complete") true (get completed current-interaction)))
    )
        (map-set user-interactions
            { user: user, content-id: content-id }
            {
                viewed: new-viewed,
                completed: new-completed,
                rating: (get rating current-interaction),
                interaction-time: block-height
            }
        )
        
        ;; Update content metrics
        (if (and (is-eq interaction-type "view") (not (get viewed current-interaction)))
            (increment-content-views content-id)
            true
        )
        
        (if (and (is-eq interaction-type "complete") (not (get completed current-interaction)))
            (increment-content-completions content-id)
            true
        )
        
        (ok true)
    )
)

;; Create new interaction
(define-private (create-new-interaction (user principal) (content-id uint) (interaction-type (string-ascii 20)))
    (let (
        (is-view (is-eq interaction-type "view"))
        (is-complete (is-eq interaction-type "complete"))
    )
        (map-set user-interactions
            { user: user, content-id: content-id }
            {
                viewed: is-view,
                completed: is-complete,
                rating: u0,
                interaction-time: block-height
            }
        )
        
        ;; Update content metrics
        (if is-view (increment-content-views content-id) true)
        (if is-complete (increment-content-completions content-id) true)
        
        (ok true)
    )
)

;; Increment content views
(define-private (increment-content-views (content-id uint))
    (let ((content (unwrap-panic (map-get? content-registry { content-id: content-id }))))
        (map-set content-registry
            { content-id: content-id }
            (merge content { total-views: (+ (get total-views content) u1) })
        )
        true
    )
)

;; Increment content completions
(define-private (increment-content-completions (content-id uint))
    (let ((content (unwrap-panic (map-get? content-registry { content-id: content-id }))))
        (map-set content-registry
            { content-id: content-id }
            (merge content { total-completions: (+ (get total-completions content) u1) })
        )
        true
    )
)

;; Update content rating
(define-private (update-content-rating (content-id uint) (rating uint) (is-new bool))
    (let ((content (unwrap-panic (map-get? content-registry { content-id: content-id }))))
        (map-set content-registry
            { content-id: content-id }
            (merge content { 
                total-ratings: (if is-new (+ (get total-ratings content) u1) (get total-ratings content)),
                rating-sum: (+ (get rating-sum content) rating)
            })
        )
        true
    )
)

;; Update content rating change
(define-private (update-content-rating-change (content-id uint) (old-rating uint) (new-rating uint))
    (let ((content (unwrap-panic (map-get? content-registry { content-id: content-id }))))
        (map-set content-registry
            { content-id: content-id }
            (merge content { 
                rating-sum: (+ (- (get rating-sum content) old-rating) new-rating)
            })
        )
        true
    )
)
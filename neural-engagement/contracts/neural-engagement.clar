;; Neural Engagement Platform Smart Contract

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-CREATOR-NOT-FOUND (err u103))
(define-constant ERR-INVALID-TIER (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))
(define-constant ERR-PREDICTION-CLOSED (err u106))
(define-constant ERR-INVALID-TIMESTAMP (err u107))
(define-constant ERR-INSUFFICIENT-STAKE (err u108))
(define-constant ERR-INVALID-ENGAGEMENT-SCORE (err u109))
(define-constant ERR-CONTENT-NOT-FOUND (err u110))
(define-constant ERR-INVALID-BIOMETRIC-SCORE (err u111))
(define-constant ERR-CAMPAIGN-EXPIRED (err u112))
(define-constant ERR-ALREADY-SETTLED (err u113))
(define-constant ERR-NOT-SETTLED (err u114))
(define-constant ERR-ALREADY-CLAIMED (err u115))

;; Contract Owner
(define-data-var contract-owner principal tx-sender)
(define-data-var platform-fee-rate uint u250) ;; 2.5%
(define-data-var min-engagement-score uint u50)
(define-data-var prediction-pool-fee uint u100) ;; 1%

;; Creator Profile Data
(define-map creators 
    { creator: principal }
    {
        total-engagement: uint,
        quality-score: uint,
        consistency-score: uint,
        token-supply: uint,
        revenue-earned: uint,
        content-count: uint,
        fan-count: uint,
        reputation: uint
    }
)

;; Dynamic Creator Token Values
(define-map creator-token-prices
    { creator: principal }
    {
        current-price: uint,
        last-update: uint,
        price-trend: int,
        volume-24h: uint
    }
)

;; Engagement NFT Tiers
(define-map engagement-nfts
    { creator: principal, fan: principal }
    {
        tier-level: uint, ;; 1-casual, 2-active, 3-super, 4-vip
        engagement-score: uint,
        total-contributions: uint,
        tier-benefits: uint,
        revenue-share-rate: uint,
        mint-timestamp: uint
    }
)

;; Neural Proof-of-Engagement Data
(define-map engagement-proofs
    { user: principal, content-id: uint }
    {
        biometric-score: uint,
        authenticity-score: uint,
        interaction-quality: uint,
        timestamp: uint,
        verified: bool,
        reward-earned: uint
    }
)

;; Content Fingerprints for IP Protection
(define-map content-registry
    { content-id: uint }
    {
        creator: principal,
        content-hash: (buff 32),
        timestamp: uint,
        ip-protected: bool,
        engagement-count: uint,
        revenue-generated: uint
    }
)

;; Predictive Content Campaigns
(define-map prediction-campaigns
    { campaign-id: uint }
    {
        creator: principal,
        target-metric: uint,
        prediction-pool: uint,
        end-timestamp: uint,
        actual-result: uint,
        settled: bool,
        total-stakes: uint
    }
)

;; Fan Predictions
(define-map fan-predictions
    { campaign-id: uint, fan: principal }
    {
        predicted-value: uint,
        stake-amount: uint,
        potential-reward: uint,
        claimed: bool
    }
)

;; Cross-Platform Engagement Credits
(define-map engagement-credits
    { user: principal }
    {
        twitter-credits: uint,
        instagram-credits: uint,
        tiktok-credits: uint,
        youtube-credits: uint,
        total-credits: uint,
        conversion-rate: uint
    }
)

;; Revenue Distribution Pools
(define-map creator-revenue-pools
    { creator: principal }
    {
        immediate-pool: uint,
        fan-reward-pool: uint,
        ip-protection-pool: uint,
        collaboration-pool: uint
    }
)

;; Auto-incrementing IDs
(define-data-var next-content-id uint u1)
(define-data-var next-campaign-id uint u1)

;; Helper Functions
(define-private (calculate-tier-benefits (tier uint))
    (if (is-eq tier u1) u10  ;; casual: 10% benefits
    (if (is-eq tier u2) u25  ;; active: 25% benefits
    (if (is-eq tier u3) u50  ;; super: 50% benefits
        u100)))              ;; vip: 100% benefits
)

(define-private (calculate-revenue-share (tier uint))
    (if (is-eq tier u1) u5   ;; casual: 5% revenue share
    (if (is-eq tier u2) u10  ;; active: 10% revenue share
    (if (is-eq tier u3) u20  ;; super: 20% revenue share
        u30)))               ;; vip: 30% revenue share
)

(define-private (calculate-authenticity-score (biometric uint) (interaction uint))
    (let ((base-score (/ (+ biometric interaction) u2)))
        (if (> base-score u90) u95
        (if (> base-score u70) u80
        (if (> base-score u50) u65
            u45)))
    )
)

(define-private (calculate-interaction-quality (biometric uint) (interaction uint))
    (let ((quality-base (/ (+ (* biometric u3) interaction) u4)))
        (if (> quality-base u80) u90
        (if (> quality-base u60) u75
            u50))
    )
)

(define-private (calculate-engagement-reward (quality-score uint))
    (if (> quality-score u80) u1000000  ;; 1 STX for high quality
    (if (> quality-score u60) u500000   ;; 0.5 STX for medium quality
        u250000))                       ;; 0.25 STX for basic quality
)

(define-private (calculate-prediction-reward (predicted-value uint) (stake-amount uint))
    (let ((multiplier (if (> predicted-value u1000000) u150 u120))) ;; 1.5x or 1.2x multiplier
        (/ (* stake-amount multiplier) u100)
    )
)

;; Admin Functions
(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-fee u1000) ERR-INVALID-AMOUNT)
        (ok (var-set platform-fee-rate new-fee))
    )
)

(define-public (update-min-engagement-score (new-score uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-score u100) ERR-INVALID-ENGAGEMENT-SCORE)
        (ok (var-set min-engagement-score new-score))
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (ok (var-set contract-owner new-owner))
    )
)

;; Creator Registration and Management
(define-public (register-creator)
    (let ((creator tx-sender))
        (asserts! (is-none (map-get? creators { creator: creator })) ERR-ALREADY-EXISTS)
        (map-set creators
            { creator: creator }
            {
                total-engagement: u0,
                quality-score: u50,
                consistency-score: u50,
                token-supply: u1000000,
                revenue-earned: u0,
                content-count: u0,
                fan-count: u0,
                reputation: u50
            }
        )
        (map-set creator-token-prices
            { creator: creator }
            {
                current-price: u1000000, ;; 1 STX in microSTX
                last-update: block-height,
                price-trend: 0,
                volume-24h: u0
            }
        )
        (map-set creator-revenue-pools
            { creator: creator }
            {
                immediate-pool: u0,
                fan-reward-pool: u0,
                ip-protection-pool: u0,
                collaboration-pool: u0
            }
        )
        (ok true)
    )
)

(define-public (mint-engagement-nft (creator principal) (tier uint))
    (let 
        ((fan tx-sender)
         (existing-nft (map-get? engagement-nfts { creator: creator, fan: fan })))
        (asserts! (and (>= tier u1) (<= tier u4)) ERR-INVALID-TIER)
        (asserts! (is-some (map-get? creators { creator: creator })) ERR-CREATOR-NOT-FOUND)
        
        (map-set engagement-nfts
            { creator: creator, fan: fan }
            {
                tier-level: tier,
                engagement-score: u0,
                total-contributions: u0,
                tier-benefits: (calculate-tier-benefits tier),
                revenue-share-rate: (calculate-revenue-share tier),
                mint-timestamp: block-height
            }
        )
        
        ;; Update creator fan count
        (match (map-get? creators { creator: creator })
            creator-data
            (map-set creators
                { creator: creator }
                (merge creator-data { fan-count: (+ (get fan-count creator-data) u1) })
            )
            false
        )
        (ok true)
    )
)

(define-public (submit-engagement-proof (content-id uint) (biometric-score uint) (interaction-data uint))
    (let ((user tx-sender))
        (asserts! (and (>= biometric-score u1) (<= biometric-score u100)) ERR-INVALID-BIOMETRIC-SCORE)
        (asserts! (>= biometric-score (var-get min-engagement-score)) ERR-INVALID-ENGAGEMENT-SCORE)
        
        (let ((authenticity-score (calculate-authenticity-score biometric-score interaction-data))
              (quality-score (calculate-interaction-quality biometric-score interaction-data)))
            
            (map-set engagement-proofs
                { user: user, content-id: content-id }
                {
                    biometric-score: biometric-score,
                    authenticity-score: authenticity-score,
                    interaction-quality: quality-score,
                    timestamp: block-height,
                    verified: (>= authenticity-score u70),
                    reward-earned: (calculate-engagement-reward quality-score)
                }
            )
            
            ;; Update content engagement count if content exists
            (match (map-get? content-registry { content-id: content-id })
                content-data
                (map-set content-registry
                    { content-id: content-id }
                    (merge content-data { engagement-count: (+ (get engagement-count content-data) u1) })
                )
                false
            )
            (ok authenticity-score)
        )
    )
)

(define-public (register-content (content-hash (buff 32)))
    (let 
        ((creator tx-sender)
         (content-id (var-get next-content-id)))
        
        (asserts! (is-some (map-get? creators { creator: creator })) ERR-CREATOR-NOT-FOUND)
        
        (map-set content-registry
            { content-id: content-id }
            {
                creator: creator,
                content-hash: content-hash,
                timestamp: block-height,
                ip-protected: true,
                engagement-count: u0,
                revenue-generated: u0
            }
        )
        
        (var-set next-content-id (+ content-id u1))
        
        ;; Update creator content count
        (match (map-get? creators { creator: creator })
            creator-data
            (map-set creators
                { creator: creator }
                (merge creator-data { content-count: (+ (get content-count creator-data) u1) })
            )
            false
        )
        (ok content-id)
    )
)

(define-public (create-prediction-campaign (target-metric uint) (duration uint))
    (let 
        ((creator tx-sender)
         (campaign-id (var-get next-campaign-id))
         (end-time (+ block-height duration)))
        
        (asserts! (is-some (map-get? creators { creator: creator })) ERR-CREATOR-NOT-FOUND)
        (asserts! (> target-metric u0) ERR-INVALID-AMOUNT)
        (asserts! (> duration u0) ERR-INVALID-TIMESTAMP)
        
        (map-set prediction-campaigns
            { campaign-id: campaign-id }
            {
                creator: creator,
                target-metric: target-metric,
                prediction-pool: u0,
                end-timestamp: end-time,
                actual-result: u0,
                settled: false,
                total-stakes: u0
            }
        )
        
        (var-set next-campaign-id (+ campaign-id u1))
        (ok campaign-id)
    )
)

(define-public (stake-on-prediction (campaign-id uint) (predicted-value uint) (stake-amount uint))
    (let ((fan tx-sender))
        (asserts! (> stake-amount u0) ERR-INVALID-AMOUNT)
        
        (match (map-get? prediction-campaigns { campaign-id: campaign-id })
            campaign-data
            (begin
                (asserts! (< block-height (get end-timestamp campaign-data)) ERR-PREDICTION-CLOSED)
                
                (map-set fan-predictions
                    { campaign-id: campaign-id, fan: fan }
                    {
                        predicted-value: predicted-value,
                        stake-amount: stake-amount,
                        potential-reward: (calculate-prediction-reward predicted-value stake-amount),
                        claimed: false
                    }
                )
                
                (map-set prediction-campaigns
                    { campaign-id: campaign-id }
                    (merge campaign-data 
                        { 
                            prediction-pool: (+ (get prediction-pool campaign-data) stake-amount),
                            total-stakes: (+ (get total-stakes campaign-data) u1)
                        }
                    )
                )
                (ok true)
            )
            ERR-CONTENT-NOT-FOUND
        )
    )
)

(define-public (settle-prediction-campaign (campaign-id uint) (actual-result uint))
    (let ((settler tx-sender))
        (match (map-get? prediction-campaigns { campaign-id: campaign-id })
            campaign-data
            (begin
                (asserts! (is-eq settler (get creator campaign-data)) ERR-NOT-AUTHORIZED)
                (asserts! (>= block-height (get end-timestamp campaign-data)) ERR-CAMPAIGN-EXPIRED)
                (asserts! (not (get settled campaign-data)) ERR-ALREADY-SETTLED)
                
                (map-set prediction-campaigns
                    { campaign-id: campaign-id }
                    (merge campaign-data 
                        { 
                            actual-result: actual-result,
                            settled: true
                        }
                    )
                )
                (ok true)
            )
            ERR-CONTENT-NOT-FOUND
        )
    )
)

(define-public (claim-prediction-reward (campaign-id uint))
    (let ((fan tx-sender))
        (match (map-get? fan-predictions { campaign-id: campaign-id, fan: fan })
            prediction-data
            (match (map-get? prediction-campaigns { campaign-id: campaign-id })
                campaign-data
                (begin
                    (asserts! (get settled campaign-data) ERR-NOT-SETTLED)
                    (asserts! (not (get claimed prediction-data)) ERR-ALREADY-CLAIMED)
                    
                    (let ((accuracy (calculate-prediction-accuracy 
                                        (get predicted-value prediction-data) 
                                        (get actual-result campaign-data))))
                        (if (> accuracy u80) ;; High accuracy threshold
                            (begin
                                (map-set fan-predictions
                                    { campaign-id: campaign-id, fan: fan }
                                    (merge prediction-data { claimed: true })
                                )
                                (ok (get potential-reward prediction-data))
                            )
                            (ok u0) ;; No reward for low accuracy
                        )
                    )
                )
                ERR-CONTENT-NOT-FOUND
            )
            ERR-CONTENT-NOT-FOUND
        )
    )
)

(define-private (calculate-prediction-accuracy (predicted uint) (actual uint))
    (let ((difference (if (> predicted actual) 
                          (- predicted actual) 
                          (- actual predicted)))
          (percentage-diff (/ (* difference u100) actual)))
        (if (<= percentage-diff u10) u100  ;; 100% accuracy for <10% difference
        (if (<= percentage-diff u20) u85   ;; 85% accuracy for <20% difference
        (if (<= percentage-diff u50) u60   ;; 60% accuracy for <50% difference
            u0)))                          ;; 0% accuracy for >50% difference
    )
)

(define-public (update-engagement-credits (platform (string-ascii 20)) (credits uint))
    (let ((user tx-sender))
        (match (map-get? engagement-credits { user: user })
            current-credits
            (let ((new-total (+ (get total-credits current-credits) credits)))
                (map-set engagement-credits
                    { user: user }
                    (merge current-credits { total-credits: new-total })
                )
                (ok new-total)
            )
            (begin
                (map-set engagement-credits
                    { user: user }
                    {
                        twitter-credits: (if (is-eq platform "twitter") credits u0),
                        instagram-credits: (if (is-eq platform "instagram") credits u0),
                        tiktok-credits: (if (is-eq platform "tiktok") credits u0),
                        youtube-credits: (if (is-eq platform "youtube") credits u0),
                        total-credits: credits,
                        conversion-rate: u100
                    }
                )
                (ok credits)
            )
        )
    )
)

;; Read-only functions
(define-read-only (get-creator-info (creator principal))
    (map-get? creators { creator: creator })
)

(define-read-only (get-engagement-nft (creator principal) (fan principal))
    (map-get? engagement-nfts { creator: creator, fan: fan })
)

(define-read-only (get-content-info (content-id uint))
    (map-get? content-registry { content-id: content-id })
)

(define-read-only (get-prediction-campaign (campaign-id uint))
    (map-get? prediction-campaigns { campaign-id: campaign-id })
)

(define-read-only (get-fan-prediction (campaign-id uint) (fan principal))
    (map-get? fan-predictions { campaign-id: campaign-id, fan: fan })
)

(define-read-only (get-engagement-proof (user principal) (content-id uint))
    (map-get? engagement-proofs { user: user, content-id: content-id })
)

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate)
)

(define-read-only (get-next-content-id)
    (var-get next-content-id)
)

(define-read-only (get-next-campaign-id)
    (var-get next-campaign-id)
)
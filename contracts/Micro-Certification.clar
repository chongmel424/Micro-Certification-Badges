(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-teacher (err u101))
(define-constant err-not-found (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-not-owner (err u104))
(define-constant err-insufficient-badges (err u105))
(define-constant err-invalid-degree (err u106))
(define-constant err-assessment-not-found (err u107))
(define-constant err-already-attempted (err u108))
(define-constant err-insufficient-score (err u109))
(define-constant err-not-verified (err u110))
(define-constant err-already-verified (err u111))
(define-constant err-cannot-self-verify (err u112))
(define-constant err-assessment-incomplete (err u113))
(define-constant err-badge-expired (err u114))
(define-constant err-badge-still-valid (err u115))
(define-constant err-no-expiration (err u116))

(define-non-fungible-token micro-badge uint)
(define-non-fungible-token degree-certificate uint)

(define-data-var last-badge-id uint u0)
(define-data-var last-degree-id uint u0)
(define-data-var last-assessment-id uint u0)
(define-data-var total-assessments-completed uint u0)
(define-data-var total-verifications uint u0)
(define-data-var total-renewals uint u0)

(define-map teachers principal bool)
(define-map badge-data uint {
    title: (string-ascii 50),
    subject: (string-ascii 30),
    description: (string-ascii 200),
    issued-to: principal,
    issued-by: principal,
    issued-at: uint
})

(define-map degree-data uint {
    title: (string-ascii 50),
    field: (string-ascii 30),
    issued-to: principal,
    badge-ids: (list 20 uint),
    issued-at: uint,
    total-badges: uint
})

(define-map student-badges principal (list 50 uint))
(define-map student-degrees principal (list 10 uint))
(define-map badge-subjects (string-ascii 30) (list 100 uint))

(define-map skill-assessments uint {
    title: (string-ascii 50),
    subject: (string-ascii 30),
    description: (string-ascii 200),
    created-by: principal,
    min-score: uint,
    max-score: uint,
    verification-required: bool,
    created-at: uint,
    active: bool
})

(define-map assessment-attempts {student: principal, assessment-id: uint} {
    score: uint,
    completed-at: uint,
    verified: bool,
    verification-count: uint,
    passed: bool
})

(define-map peer-verifications {student: principal, assessment-id: uint, verifier: principal} {
    verified: bool,
    verification-score: uint,
    verified-at: uint
})

(define-map student-reputation principal {
    verification-count: uint,
    verified-by-count: uint,
    assessment-success-rate: uint,
    total-assessments: uint
})

(define-map badge-expiration uint {
    expires-at: uint,
    validity-period: uint,
    renewable: bool,
    renewal-count: uint,
    last-renewed-at: (optional uint)
})

(define-map badge-renewals {badge-id: uint, renewal-number: uint} {
    renewed-at: uint,
    renewed-by: principal,
    previous-expiry: uint,
    new-expiry: uint
})

(define-read-only (get-last-token-id)
    (ok (var-get last-badge-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? micro-badge token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-owner)
        (nft-transfer? micro-badge token-id sender recipient)
    )
)

(define-public (register-teacher (teacher principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set teachers teacher true)
        (ok true)
    )
)

(define-public (revoke-teacher (teacher principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set teachers teacher false)
        (ok true)
    )
)

(define-public (issue-badge (student principal) (title (string-ascii 50)) (subject (string-ascii 30)) (description (string-ascii 200)))
    (let
        (
            (badge-id (+ (var-get last-badge-id) u1))
            (current-badges (default-to (list) (map-get? student-badges student)))
            (subject-badges (default-to (list) (map-get? badge-subjects subject)))
        )
        (asserts! (default-to false (map-get? teachers tx-sender)) err-not-teacher)
        (try! (nft-mint? micro-badge badge-id student))
        (map-set badge-data badge-id {
            title: title,
            subject: subject,
            description: description,
            issued-to: student,
            issued-by: tx-sender,
            issued-at: stacks-block-height
        })
        (map-set student-badges student (unwrap-panic (as-max-len? (append current-badges badge-id) u50)))
        (map-set badge-subjects subject (unwrap-panic (as-max-len? (append subject-badges badge-id) u100)))
        (var-set last-badge-id badge-id)
        (ok badge-id)
    )
)

(define-public (stack-badges-to-degree (badge-ids (list 20 uint)) (degree-title (string-ascii 50)) (field (string-ascii 30)))
    (let
        (
            (degree-id (+ (var-get last-degree-id) u1))
            (student-badge-list (default-to (list) (map-get? student-badges tx-sender)))
            (current-degrees (default-to (list) (map-get? student-degrees tx-sender)))
        )
        (asserts! (>= (len badge-ids) u5) err-insufficient-badges)
        (asserts! (check-badge-ownership badge-ids student-badge-list) err-not-owner)
        (try! (nft-mint? degree-certificate degree-id tx-sender))
        (map-set degree-data degree-id {
            title: degree-title,
            field: field,
            issued-to: tx-sender,
            badge-ids: badge-ids,
            issued-at: stacks-block-height,
            total-badges: (len badge-ids)
        })
        (map-set student-degrees tx-sender (unwrap-panic (as-max-len? (append current-degrees degree-id) u10)))
        (var-set last-degree-id degree-id)
        (ok degree-id)
    )
)

(define-private (check-badge-ownership (badge-ids (list 20 uint)) (owned-badges (list 50 uint)))
    (is-eq (len badge-ids) (len (filter is-badge-owned badge-ids)))
)

(define-private (is-badge-owned (badge-id uint))
    (match (nft-get-owner? micro-badge badge-id)
        owner (is-eq owner tx-sender)
        false
    )
)

(define-read-only (get-badge-info (badge-id uint))
    (map-get? badge-data badge-id)
)

(define-read-only (get-degree-info (degree-id uint))
    (map-get? degree-data degree-id)
)

(define-read-only (is-teacher (address principal))
    (default-to false (map-get? teachers address))
)

(define-read-only (get-student-badges (student principal))
    (default-to (list) (map-get? student-badges student))
)

(define-read-only (get-student-degrees (student principal))
    (default-to (list) (map-get? student-degrees student))
)

(define-read-only (get-badges-by-subject (subject (string-ascii 30)))
    (default-to (list) (map-get? badge-subjects subject))
)

(define-read-only (count-student-badges (student principal))
    (len (get-student-badges student))
)

(define-read-only (count-student-degrees (student principal))
    (len (get-student-degrees student))
)

(define-read-only (get-badge-count)
    (var-get last-badge-id)
)

(define-read-only (get-degree-count)
    (var-get last-degree-id)
)

(define-public (batch-issue-badges (students (list 10 principal)) (title (string-ascii 50)) (subject (string-ascii 30)) (description (string-ascii 200)))
    (begin
        (asserts! (default-to false (map-get? teachers tx-sender)) err-not-teacher)
        (ok (map issue-badge-to-student students))
    )
)

(define-private (issue-badge-to-student (student principal))
    (let
        (
            (badge-id (+ (var-get last-badge-id) u1))
            (current-badges (default-to (list) (map-get? student-badges student)))
        )
        (match (nft-mint? micro-badge badge-id student)
            success (begin
                (map-set badge-data badge-id {
                    title: "Batch Badge",
                    subject: "General",
                    description: "Batch issued badge",
                    issued-to: student,
                    issued-by: tx-sender,
                    issued-at: stacks-block-height
                })
                (map-set student-badges student (unwrap-panic (as-max-len? (append current-badges badge-id) u50)))
                (var-set last-badge-id badge-id)
                badge-id
            )
            error u0
        )
    )
)

(define-read-only (get-teacher-issued-badges (teacher principal))
    (list)
)

(define-private (is-badge-by-teacher (badge-id uint) (teacher principal))
    (match (map-get? badge-data badge-id)
        badge-info (is-eq (get issued-by badge-info) teacher)
        false
    )
)

(define-public (validate-degree-requirements (field (string-ascii 30)) (required-subjects (list 5 (string-ascii 30))))
    (let
        (
            (student-badge-list (get-student-badges tx-sender))
        )
        (ok (len student-badge-list))
    )
)

(define-private (is-badge-in-subject (badge-id uint) (subject (string-ascii 30)))
    (match (map-get? badge-data badge-id)
        badge-info (is-eq (get subject badge-info) subject)
        false
    )
)

(define-read-only (get-contract-stats)
    {
        total-badges: (var-get last-badge-id),
        total-degrees: (var-get last-degree-id),
        contract-owner: contract-owner
    }
)

(define-public (create-skill-assessment (title (string-ascii 50)) (subject (string-ascii 30)) (description (string-ascii 200)) (min-score uint) (max-score uint) (verification-required bool))
    (let (
        (assessment-id (+ (var-get last-assessment-id) u1))
    )
        (asserts! (default-to false (map-get? teachers tx-sender)) err-not-teacher)
        (asserts! (> max-score min-score) err-invalid-degree)
        
        (map-set skill-assessments assessment-id {
            title: title,
            subject: subject,
            description: description,
            created-by: tx-sender,
            min-score: min-score,
            max-score: max-score,
            verification-required: verification-required,
            created-at: stacks-block-height,
            active: true
        })
        
        (var-set last-assessment-id assessment-id)
        (ok assessment-id)
    )
)

(define-public (submit-assessment-attempt (assessment-id uint) (score uint))
    (let (
        (assessment-data (unwrap! (map-get? skill-assessments assessment-id) err-assessment-not-found))
        (attempt-key {student: tx-sender, assessment-id: assessment-id})
        (existing-attempt (map-get? assessment-attempts attempt-key))
        (student-rep (default-to {verification-count: u0, verified-by-count: u0, assessment-success-rate: u0, total-assessments: u0} 
                       (map-get? student-reputation tx-sender)))
    )
        (asserts! (get active assessment-data) err-assessment-not-found)
        (asserts! (is-none existing-attempt) err-already-attempted)
        (asserts! (<= score (get max-score assessment-data)) err-invalid-degree)
        
        (let (
            (passed (>= score (get min-score assessment-data)))
            (needs-verification (and passed (get verification-required assessment-data)))
        )
            (map-set assessment-attempts attempt-key {
                score: score,
                completed-at: stacks-block-height,
                verified: (not needs-verification),
                verification-count: u0,
                passed: passed
            })
            
            (map-set student-reputation tx-sender {
                verification-count: (get verification-count student-rep),
                verified-by-count: (get verified-by-count student-rep),
                assessment-success-rate: (if (> (+ (get total-assessments student-rep) u1) u0)
                    (/ (* (+ (if passed u1 u0) (* (get assessment-success-rate student-rep) (get total-assessments student-rep))) u100)
                       (+ (get total-assessments student-rep) u1))
                    u0),
                total-assessments: (+ (get total-assessments student-rep) u1)
            })
            
            (var-set total-assessments-completed (+ (var-get total-assessments-completed) u1))
            (ok passed)
        )
    )
)

(define-public (verify-peer-assessment (student principal) (assessment-id uint) (verification-score uint) (approve bool))
    (let (
        (assessment-data (unwrap! (map-get? skill-assessments assessment-id) err-assessment-not-found))
        (attempt-key {student: student, assessment-id: assessment-id})
        (attempt-data (unwrap! (map-get? assessment-attempts attempt-key) err-assessment-not-found))
        (verification-key {student: student, assessment-id: assessment-id, verifier: tx-sender})
        (existing-verification (map-get? peer-verifications verification-key))
        (verifier-rep (default-to {verification-count: u0, verified-by-count: u0, assessment-success-rate: u0, total-assessments: u0}
                        (map-get? student-reputation tx-sender)))
        (student-rep (default-to {verification-count: u0, verified-by-count: u0, assessment-success-rate: u0, total-assessments: u0}
                       (map-get? student-reputation student)))
    )
        (asserts! (not (is-eq student tx-sender)) err-cannot-self-verify)
        (asserts! (get passed attempt-data) err-assessment-incomplete)
        (asserts! (get verification-required assessment-data) err-not-verified)
        (asserts! (is-none existing-verification) err-already-verified)
        
        (map-set peer-verifications verification-key {
            verified: approve,
            verification-score: verification-score,
            verified-at: stacks-block-height
        })
        
        (let (
            (new-verification-count (+ (get verification-count attempt-data) u1))
            (is-fully-verified (>= new-verification-count u3))
        )
            (map-set assessment-attempts attempt-key
                (merge attempt-data {
                    verification-count: new-verification-count,
                    verified: is-fully-verified
                })
            )
            
            (map-set student-reputation tx-sender
                (merge verifier-rep {
                    verification-count: (+ (get verification-count verifier-rep) u1)
                })
            )
            
            (map-set student-reputation student
                (merge student-rep {
                    verified-by-count: (+ (get verified-by-count student-rep) u1)
                })
            )
            
            (var-set total-verifications (+ (var-get total-verifications) u1))
            (ok is-fully-verified)
        )
    )
)

(define-public (issue-badge-with-assessment (student principal) (title (string-ascii 50)) (subject (string-ascii 30)) (description (string-ascii 200)) (assessment-id uint))
    (let (
        (assessment-data (unwrap! (map-get? skill-assessments assessment-id) err-assessment-not-found))
        (attempt-key {student: student, assessment-id: assessment-id})
        (attempt-data (unwrap! (map-get? assessment-attempts attempt-key) err-assessment-not-found))
        (badge-id (+ (var-get last-badge-id) u1))
        (current-badges (default-to (list) (map-get? student-badges student)))
        (subject-badges (default-to (list) (map-get? badge-subjects subject)))
    )
        (asserts! (default-to false (map-get? teachers tx-sender)) err-not-teacher)
        (asserts! (get passed attempt-data) err-insufficient-score)
        (asserts! (get verified attempt-data) err-not-verified)
        
        (try! (nft-mint? micro-badge badge-id student))
        (map-set badge-data badge-id {
            title: title,
            subject: subject,
            description: description,
            issued-to: student,
            issued-by: tx-sender,
            issued-at: stacks-block-height
        })
        (map-set student-badges student (unwrap-panic (as-max-len? (append current-badges badge-id) u50)))
        (map-set badge-subjects subject (unwrap-panic (as-max-len? (append subject-badges badge-id) u100)))
        (var-set last-badge-id badge-id)
        (ok badge-id)
    )
)

(define-read-only (get-skill-assessment (assessment-id uint))
    (map-get? skill-assessments assessment-id)
)

(define-read-only (get-assessment-attempt (student principal) (assessment-id uint))
    (map-get? assessment-attempts {student: student, assessment-id: assessment-id})
)

(define-read-only (get-peer-verification (student principal) (assessment-id uint) (verifier principal))
    (map-get? peer-verifications {student: student, assessment-id: assessment-id, verifier: verifier})
)

(define-read-only (get-student-reputation (student principal))
    (default-to {verification-count: u0, verified-by-count: u0, assessment-success-rate: u0, total-assessments: u0}
                (map-get? student-reputation student))
)

(define-read-only (get-assessment-stats)
    {
        total-assessments: (var-get last-assessment-id),
        total-completions: (var-get total-assessments-completed),
        total-verifications: (var-get total-verifications),
        completion-rate: (if (> (var-get last-assessment-id) u0)
            (/ (* (var-get total-assessments-completed) u100) (var-get last-assessment-id))
            u0)
    }
)

(define-read-only (check-badge-eligibility (student principal) (assessment-id uint))
    (match (map-get? assessment-attempts {student: student, assessment-id: assessment-id})
        attempt-data {
            passed: (get passed attempt-data),
            verified: (get verified attempt-data),
            eligible-for-badge: (and (get passed attempt-data) (get verified attempt-data))
        }
        {
            passed: false,
            verified: false,
            eligible-for-badge: false
        }
    )
)

(define-read-only (get-verification-progress (student principal) (assessment-id uint))
    (match (map-get? assessment-attempts {student: student, assessment-id: assessment-id})
        attempt-data {
            verification-count: (get verification-count attempt-data),
            required-verifications: u3,
            is-verified: (get verified attempt-data)
        }
        {
            verification-count: u0,
            required-verifications: u3,
            is-verified: false
        }
    )
)

(define-public (set-badge-expiration (badge-id uint) (validity-period uint) (renewable bool))
    (let (
        (badge-info (unwrap! (map-get? badge-data badge-id) err-not-found))
        (expiry-block (+ stacks-block-height validity-period))
    )
        (asserts! (default-to false (map-get? teachers tx-sender)) err-not-teacher)
        (asserts! (> validity-period u0) err-invalid-degree)
        
        (map-set badge-expiration badge-id {
            expires-at: expiry-block,
            validity-period: validity-period,
            renewable: renewable,
            renewal-count: u0,
            last-renewed-at: none
        })
        (ok expiry-block)
    )
)

(define-public (renew-badge (badge-id uint))
    (let (
        (badge-info (unwrap! (map-get? badge-data badge-id) err-not-found))
        (expiration-info (unwrap! (map-get? badge-expiration badge-id) err-no-expiration))
        (badge-owner (unwrap! (nft-get-owner? micro-badge badge-id) err-not-found))
    )
        (asserts! (or 
            (is-eq tx-sender badge-owner)
            (default-to false (map-get? teachers tx-sender)))
            err-not-owner)
        (asserts! (get renewable expiration-info) err-invalid-degree)
        (asserts! (>= stacks-block-height (get expires-at expiration-info)) err-badge-still-valid)
        
        (let (
            (new-expiry (+ stacks-block-height (get validity-period expiration-info)))
            (current-renewal-count (get renewal-count expiration-info))
            (renewal-number (+ current-renewal-count u1))
        )
            (map-set badge-renewals {badge-id: badge-id, renewal-number: renewal-number} {
                renewed-at: stacks-block-height,
                renewed-by: tx-sender,
                previous-expiry: (get expires-at expiration-info),
                new-expiry: new-expiry
            })
            
            (map-set badge-expiration badge-id
                (merge expiration-info {
                    expires-at: new-expiry,
                    renewal-count: renewal-number,
                    last-renewed-at: (some stacks-block-height)
                })
            )
            
            (var-set total-renewals (+ (var-get total-renewals) u1))
            (ok new-expiry)
        )
    )
)

(define-public (issue-badge-with-expiration (student principal) (title (string-ascii 50)) (subject (string-ascii 30)) (description (string-ascii 200)) (validity-period uint))
    (let (
        (badge-id (+ (var-get last-badge-id) u1))
        (current-badges (default-to (list) (map-get? student-badges student)))
        (subject-badges (default-to (list) (map-get? badge-subjects subject)))
        (expiry-block (+ stacks-block-height validity-period))
    )
        (asserts! (default-to false (map-get? teachers tx-sender)) err-not-teacher)
        (asserts! (> validity-period u0) err-invalid-degree)
        (try! (nft-mint? micro-badge badge-id student))
        
        (map-set badge-data badge-id {
            title: title,
            subject: subject,
            description: description,
            issued-to: student,
            issued-by: tx-sender,
            issued-at: stacks-block-height
        })
        
        (map-set badge-expiration badge-id {
            expires-at: expiry-block,
            validity-period: validity-period,
            renewable: true,
            renewal-count: u0,
            last-renewed-at: none
        })
        
        (map-set student-badges student (unwrap-panic (as-max-len? (append current-badges badge-id) u50)))
        (map-set badge-subjects subject (unwrap-panic (as-max-len? (append subject-badges badge-id) u100)))
        (var-set last-badge-id badge-id)
        (ok badge-id)
    )
)

(define-read-only (get-badge-expiration-info (badge-id uint))
    (map-get? badge-expiration badge-id)
)

(define-read-only (is-badge-expired (badge-id uint))
    (match (map-get? badge-expiration badge-id)
        expiration-info (ok (>= stacks-block-height (get expires-at expiration-info)))
        err-no-expiration
    )
)

(define-read-only (get-badge-status (badge-id uint))
    (match (map-get? badge-expiration badge-id)
        expiration-info 
            (let (
                (is-expired (>= stacks-block-height (get expires-at expiration-info)))
                (blocks-remaining (if is-expired u0 (- (get expires-at expiration-info) stacks-block-height)))
            )
                (ok {
                    is-expired: is-expired,
                    expires-at: (get expires-at expiration-info),
                    blocks-remaining: blocks-remaining,
                    renewable: (get renewable expiration-info),
                    renewal-count: (get renewal-count expiration-info),
                    validity-period: (get validity-period expiration-info)
                })
            )
        (ok {
            is-expired: false,
            expires-at: u0,
            blocks-remaining: u0,
            renewable: false,
            renewal-count: u0,
            validity-period: u0
        })
    )
)

(define-read-only (get-renewal-history (badge-id uint) (renewal-number uint))
    (map-get? badge-renewals {badge-id: badge-id, renewal-number: renewal-number})
)

(define-read-only (count-badge-renewals (badge-id uint))
    (match (map-get? badge-expiration badge-id)
        expiration-info (ok (get renewal-count expiration-info))
        err-no-expiration
    )
)

(define-read-only (get-expiring-soon (badge-id uint) (threshold-blocks uint))
    (match (map-get? badge-expiration badge-id)
        expiration-info
            (let (
                (blocks-until-expiry (if (>= stacks-block-height (get expires-at expiration-info))
                    u0
                    (- (get expires-at expiration-info) stacks-block-height)))
            )
                (ok {
                    expiring-soon: (and 
                        (< blocks-until-expiry threshold-blocks)
                        (> blocks-until-expiry u0)),
                    blocks-until-expiry: blocks-until-expiry,
                    renewable: (get renewable expiration-info)
                })
            )
        err-no-expiration
    )
)

(define-read-only (get-total-renewals)
    (var-get total-renewals)
)

(define-read-only (get-student-active-badges (student principal))
    (let (
        (all-badges (get-student-badges student))
    )
        (ok {
            total-badges: (len all-badges),
            badge-ids: all-badges
        })
    )
)

(register-teacher contract-owner)

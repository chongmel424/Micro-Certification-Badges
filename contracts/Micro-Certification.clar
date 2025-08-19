(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-teacher (err u101))
(define-constant err-not-found (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-not-owner (err u104))
(define-constant err-insufficient-badges (err u105))
(define-constant err-invalid-degree (err u106))

(define-non-fungible-token micro-badge uint)
(define-non-fungible-token degree-certificate uint)

(define-data-var last-badge-id uint u0)
(define-data-var last-degree-id uint u0)

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

(register-teacher contract-owner)
